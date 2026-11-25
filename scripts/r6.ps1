# Relatório 6 – Autenticação e autorização (Identity, cookie HttpOnly, roles, claims e políticas)
# Uso:  .\scripts\r6.ps1
. "$PSScriptRoot\_comum.ps1"

$viteProc = $null
function Iniciar-Vite {
    $script:viteProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npm run dev' -WorkingDirectory $Front -PassThru -WindowStyle Minimized
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 700
        if ((& curl.exe -s -o NUL -w '%{http_code}' 'http://localhost:5173/') -eq '200') { Ok 'Vite em execução em http://localhost:5173'; return }
    }
    throw 'O servidor do Vite não respondeu em http://localhost:5173.'
}
function Parar-Vite { if ($script:viteProc) { & taskkill.exe /PID $script:viteProc.Id /T /F *> $null; $script:viteProc = $null } }

try {
    Exigir-Fase 'r5'
    Verificar-Ferramentas -Ef -Node
    Aplicar-Fase 'r6'
    Configurar-Segredos
    $s = Senhas-Dev
    Compilar

    Passo 'Migration do Identity'
    $ef = @('--project', $Web, '--no-build')
    $lista = (& dotnet ef migrations list @ef 2>$null) -join ' '
    if ($lista -notmatch 'AdicionarIdentity') {
        [void](Executar 'dotnet' (@('ef', 'migrations', 'add', 'AdicionarIdentity') + $ef) -UltimasLinhas 3)
        Compilar
    }
    [void](Executar 'dotnet' (@('ef', 'database', 'update') + $ef) -UltimasLinhas 3)
    Iniciar-Api -NomeLog 'api-r6'     # cria roles e usuários de seed (senhas vindas de User Secrets)

    $jar = Join-Path $Tmp 'comum.txt'; $jarAdmin = Join-Path $Tmp 'admin.txt'; $jarAntigo = Join-Path $Tmp 'antigo.txt'

    # ---------------------------------------------------------------- Fig. 6.1 – login
    Figura 'Fig_6_1' 'Login válido (204 + cookie) e inválidos (401 idêntico para senha errada e e-mail inexistente)'
    Passo 'Login válido (usuario@portal.local)'
    $corpoLogin = (@{ email = 'usuario@portal.local'; senha = $s.Usuario } | ConvertTo-Json -Compress)
    [void](Http -Metodo POST -Url '/api/conta/login' -Corpo $corpoLogin -CorpoExibido '{"email":"usuario@portal.local","senha":"(senha de User Secrets, oculta)"}' -SalvarCookies $jar -MaxLinhas 2)
    Passo 'Senha errada (admin@portal.local)'
    [void](Http -Metodo POST -Url '/api/conta/login' -Corpo '{"email":"admin@portal.local","senha":"SenhaErrada123!"}' -MaxLinhas 8)
    Passo 'E-mail inexistente'
    [void](Http -Metodo POST -Url '/api/conta/login' -Corpo '{"email":"naoexiste@portal.local","senha":"SenhaErrada123!"}' -MaxLinhas 8)
    Capturar 'Fig_6_1'

    # ---------------------------------------------------------------- Fig. 6.3 – matriz de autorização
    Figura 'Fig_6_3' 'Matriz de autorização com os três perfis (anônimo, usuário comum e administrador)'
    [void](Login 'admin@portal.local' $s.Admin $jarAdmin)
    $base = Http -Url "/api/tarefas/$SeedId" -Cookies $jarAdmin -Silencioso
    $put = @{ titulo = $base.Json.titulo; descricao = 'Matriz de autorização'; prioridade = $base.Json.prioridade
              prazo = $base.Json.prazo; situacao = $base.Json.situacao; rowVersion = $base.Json.rowVersion } | ConvertTo-Json -Compress
    $nova = '{"titulo":"Tarefa da matriz","prioridade":"Normal","prazo":"2026-12-20"}'
    $linhas = @()
    foreach ($perfil in @(@{ Nome = 'Anônimo'; Jar = $null }, @{ Nome = 'Usuário comum'; Jar = $jar }, @{ Nome = 'Administrador'; Jar = $jarAdmin })) {
        $get = StatusHttp GET '/api/tarefas' $perfil.Jar
        $post = Http -Metodo POST -Url '/api/tarefas' -Corpo $nova -Cookies $perfil.Jar -Silencioso
        $atual = Http -Url "/api/tarefas/$SeedId" -Cookies $jarAdmin -Silencioso
        $corpoPut = $put -replace '"rowVersion":"[^"]*"', ('"rowVersion":"' + $atual.Json.rowVersion + '"')
        $pt = StatusHttp PUT "/api/tarefas/$SeedId" $perfil.Jar $corpoPut
        $alvo = if ($post.Json.id) { $post.Json.id } else { (Http -Metodo POST -Url '/api/tarefas' -Corpo $nova -Cookies $jarAdmin -Silencioso).Json.id }
        $del = StatusHttp DELETE "/api/tarefas/$alvo" $perfil.Jar
        $linhas += [pscustomobject]@{ Perfil = $perfil.Nome; 'GET /api/tarefas' = $get; 'POST /api/tarefas' = $post.Status
                                      'PUT /api/tarefas/{id}' = $pt; 'DELETE /api/tarefas/{id}' = $del }
    }
    $linhas | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host 'Esperado: anônimo 401 em tudo; usuário comum 200/201 e 403 em PUT (sem a claim) e DELETE (sem a role);' -ForegroundColor DarkGray
    Write-Host '          administrador 200/201/200/204 (role Administrador e claim permissao=editar-outra-equipe).' -ForegroundColor DarkGray
    Capturar 'Fig_6_3'

    # ---------------------------------------------------------------- Fig. 6.4 – DELETE fora da SPA
    Figura 'Fig_6_4' 'DELETE com curl, fora da SPA, como usuário comum: 403 (a regra está no servidor)'
    $alvo = (Http -Metodo POST -Url '/api/tarefas' -Corpo $nova -Cookies $jarAdmin -Silencioso).Json.id
    Write-Host "PS> curl.exe -k -b comum.txt -i -X DELETE $ApiHttps/api/tarefas/$alvo" -ForegroundColor Gray
    [void](Http -Metodo DELETE -Url "/api/tarefas/$alvo" -Cookies $jar -MaxLinhas 4)
    Passo 'Auditoria no log da API (sem dados sensíveis)'
    LogApi | Where-Object { $_ -match 'Acesso negado' } | Select-Object -Last 2 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Capturar 'Fig_6_4'

    # ---------------------------------------------------------------- Fig. 6.2 – logout invalida o cookie antigo
    Figura 'Fig_6_2' 'Logout e reutilização do cookie antigo (cookie jar do curl): a segunda chamada recebe 401'
    Copy-Item $jar $jarAntigo -Force
    Write-Host "PS> Copy-Item comum.txt antigo.txt" -ForegroundColor Gray
    [void](Http -Url '/api/conta/me' -Cookies $jar -MaxLinhas 8)
    [void](Http -Metodo POST -Url '/api/conta/logout' -Cookies $jar -SalvarCookies $jar -MaxLinhas 2)
    Passo 'Reutilizando o cookie antigo (antigo.txt)'
    [void](Http -Url '/api/tarefas' -Cookies $jarAntigo -MaxLinhas 2)
    Capturar 'Fig_6_2'

    # ---------------------------------------------------------------- Fig. 6.7b – nada sensível nos logs
    Figura 'Fig_6_7b' 'Inspeção dos logs: nenhuma senha, cookie ou connection string registrada'
    $log = (LogApi) -join "`n"
    $verificacoes = [ordered]@{
        'Senha do administrador'   = $s.Admin
        'Senha do usuário comum'   = $s.Usuario
        'Senha errada de teste'    = 'SenhaErrada123!'
        'Valor do cookie de sessão'= ((Get-Content $jarAntigo | Where-Object { $_ -match 'portaltarefas.auth' }) -split "`t")[-1]
        'Connection string'        = 'Trusted_Connection'
    }
    foreach ($k in $verificacoes.Keys) {
        $n = if ($verificacoes[$k]) { ([regex]::Matches($log, [regex]::Escape($verificacoes[$k]))).Count } else { 0 }
        $cor = if ($n -eq 0) { 'Green' } else { 'Red' }
        Write-Host ("  {0,-28} ocorrências no log: {1}" -f $k, $n) -ForegroundColor $cor
    }
    Passo 'Linhas de falha de login registradas (sem e-mail e sem senha)'
    LogApi | Where-Object { $_ -match 'Falha de login' } | Select-Object -Last 2 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Capturar 'Fig_6_7b'

    # ---------------------------------------------------------------- SPA (navegador automatizado)
    Push-Location $Front
    try { [void](Executar 'npm.cmd' @('run', 'build') -UltimasLinhas 3) } finally { Pop-Location }
    Iniciar-Vite
    $nav = Join-Path $PSScriptRoot '.nav'
    if (-not (Test-Path (Join-Path $nav 'node_modules\playwright-core'))) {
        New-Item -ItemType Directory -Force $nav | Out-Null
        if (-not (Test-Path (Join-Path $nav 'package.json'))) { '{ "private": true }' | Set-Content (Join-Path $nav 'package.json') -Encoding ASCII }
        [void](Executar 'npm.cmd' @('install', '--prefix', $nav, 'playwright-core@1', '--no-fund', '--no-audit') -UltimasLinhas 2)
    }
    Write-Host 'O Chrome vai abrir e ser controlado sozinho. Não clique em nada até o fim.' -ForegroundColor Cyan
    $env:PT_SENHA_USUARIO = $s.Usuario; $env:PT_SENHA_ADMIN = $s.Admin
    try { & node (Join-Path $PSScriptRoot 'navegador.mjs') 'r6' } finally { Remove-Item env:PT_SENHA_USUARIO, env:PT_SENHA_ADMIN -ErrorAction SilentlyContinue }
    if ($LASTEXITCODE -ne 0) { throw 'A automação do navegador falhou (cenário r6).' }

    Figura 'Fig_6_7' 'Armazenamento do navegador autenticado: nenhum token em localStorage/sessionStorage; cookie HttpOnly'
    $arm = Get-Content (Join-Path $Tmp 'armazenamento-6_7.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Página inspecionada: $($arm.url)" -ForegroundColor White
    Write-Host ("  localStorage   - chaves: {0}" -f $(if (@($arm.local).Count) { ($arm.local -join ', ') } else { '(vazio)' })) -ForegroundColor Green
    Write-Host ("  sessionStorage - chaves: {0}" -f $(if (@($arm.sessao).Count) { ($arm.sessao -join ', ') } else { '(vazio)' })) -ForegroundColor Green
    Write-Host ("  document.cookie visível ao JavaScript: {0}" -f $(if ($arm.cookieJs) { $arm.cookieJs } else { '(vazio - o cookie de sessão é HttpOnly)' })) -ForegroundColor Green
    Passo 'Cookies do navegador'
    $arm.cookies | Select-Object nome, dominio, httpOnly, secure, sameSite | Format-Table -AutoSize | Out-String | Write-Host
    Passo 'Logs da API: senha ou cookie registrados?'
    $log = (LogApi) -join "`n"
    foreach ($par in @(@('Senha do administrador', $s.Admin), @('Senha do usuário', $s.Usuario))) {
        $n = ([regex]::Matches($log, [regex]::Escape($par[1]))).Count
        Write-Host ("  {0,-24} ocorrências: {1}" -f $par[0], $n) -ForegroundColor $(if ($n -eq 0) { 'Green' } else { 'Red' })
    }
    Capturar 'Fig_6_7'

    Write-Host ""; Ok 'Relatório 6 concluído. Prints em .\evidencias'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem (e evidencias\_tmp\ultimo-erro.txt, se existir) para o Claude.' -ForegroundColor Red }
finally { Parar-Vite; Parar-Api }
