# Relatório 8 – Configuração por ambientes, segredos, contêineres e CI/CD
# Uso:  .\scripts\r8.ps1   (o build da imagem Docker pode levar alguns minutos)
. "$PSScriptRoot\_comum.ps1"

try {
    Exigir-Fase 'r7'
    Verificar-Ferramentas -Node
    Aplicar-Fase 'r8'

    # Arquivos que a ferramenta remota não pode gravar: o próprio script cria (conteúdo igual ao do Apêndice A)
    $semBom = New-Object System.Text.UTF8Encoding $false
    New-Item -ItemType Directory -Force (Join-Path $Raiz '.github\workflows') | Out-Null
    $ci = @'
name: ci

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - run: dotnet restore
      - run: dotnet build --no-restore -c Release
      - run: dotnet test --no-build -c Release --filter "Category!=Integracao"
      - run: dotnet list package --include-transitive > inventario-dependencias.txt
      - uses: actions/upload-artifact@v4
        with:
          name: inventario-dependencias
          path: inventario-dependencias.txt

  frontend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: PortalTarefas.Frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: npm
          cache-dependency-path: PortalTarefas.Frontend/package-lock.json
      - run: npm ci
      - run: npm test --if-present
      - run: npm run build

  imagem:
    needs: [backend, frontend]          # gate: só roda se os dois jobs passarem
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - name: Build da imagem (tag = commit)
        run: |
          IMAGE="ghcr.io/${GITHUB_REPOSITORY,,}:${GITHUB_SHA}"
          echo "IMAGE=$IMAGE" >> "$GITHUB_ENV"
          docker build --label org.opencontainers.image.revision="$GITHUB_SHA" -t "$IMAGE" .
      - name: Smoke test (liveness)
        run: |
          docker run -d --name smoke -p 8080:8080 -e ConnectionStrings__DefaultConnection="Server=ci-sem-banco" "$IMAGE"
          curl --retry 15 --retry-delay 2 --retry-connrefused -fsS http://localhost:8080/health/live
      - name: Publicar no GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u "${{ github.actor }}" --password-stdin
          docker push "$IMAGE"
'@
    [IO.File]::WriteAllText((Join-Path $Raiz '.github\workflows\ci.yml'), ($ci -replace "`r`n", "`n") + "`n", $semBom)
    $envExemplo = @'
# .env.example – copie para .env e preencha localmente (NUNCA versionar o .env)
ConnectionStrings__DefaultConnection=
MSSQL_SA_PASSWORD=
Dependencias__Url=http://localhost:8080
Seed__AdminSenha=
Seed__UsuarioSenha=
'@
    [IO.File]::WriteAllText((Join-Path $Raiz '.env.example'), ($envExemplo -replace "`r`n", "`n") + "`n", $semBom)
    Ok 'Criados .github\workflows\ci.yml e .env.example'
    Compilar

    # ---------------------------------------------------------------- Fig. 8.1 – clone novo compila
    $clone = Join-Path $env:TEMP 'portaltarefas-clone'
    if (Test-Path $clone) { Remove-Item $clone -Recurse -Force }
    $temGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
    if ($temGit) {
        Push-Location $Raiz
        try {
            if (-not (Test-Path (Join-Path $Raiz '.git'))) { & git init -q -b main *> $null }
            & git -c core.autocrlf=false add -A *> $null
            & git -c core.autocrlf=false -c user.name='Jonathas da Silva Nunes' -c user.email='jonathas@portal.local' commit -q -m 'Portal de Tarefas: relatórios 1 a 8' *> $null
        } finally { Pop-Location }
    }
    Figura 'Fig_8_1' 'Clone novo: dotnet build e npm ci && npm run build concluem sem erros'
    if ($temGit) {
        Write-Host "PS> git clone $Raiz $clone" -ForegroundColor Gray
        & git clone -q $Raiz $clone *> $null
        Push-Location $clone; Write-Host ("  commit: " + (& git log --oneline -1)); Pop-Location
    } else {
        Write-Host 'git não encontrado: cópia limpa sem bin/obj/node_modules (robocopy)' -ForegroundColor DarkYellow
        & robocopy $Raiz $clone /E /XD bin obj node_modules dist .git evidencias /NFL /NDL /NJH /NJS | Out-Null
    }
    Write-Host "Arquivos de segredo no clone: .env = $(Test-Path (Join-Path $clone '.env'))   .senhas-dev.ps1 = $(Test-Path (Join-Path $clone 'scripts\.senhas-dev.ps1'))"
    [void](Executar 'dotnet' @('build', (Join-Path $clone 'PortalTarefas.sln'), '-nologo', '-v', 'q') -UltimasLinhas 5)
    Push-Location (Join-Path $clone 'PortalTarefas.Frontend')
    try {
        [void](Executar 'npm.cmd' @('ci', '--no-fund', '--no-audit') -UltimasLinhas 2)
        [void](Executar 'npm.cmd' @('run', 'build') -UltimasLinhas 6)
    } finally { Pop-Location }
    Capturar 'Fig_8_1'

    # ---------------------------------------------------------------- Fig. 8.4 – falha segura sem connection string
    Figura 'Fig_8_4' 'Iniciar em Production sem ConnectionStrings__DefaultConnection: falha na inicialização com mensagem segura'
    $exe = Join-Path $Web 'bin\Debug\net10.0\PortalTarefas.Web.exe'
    Write-Host 'PS> $env:ASPNETCORE_ENVIRONMENT = "Production"; .\PortalTarefas.Web.exe   (sem a variável ConnectionStrings__DefaultConnection)' -ForegroundColor Gray
    $env:ASPNETCORE_ENVIRONMENT = 'Production'; $env:ASPNETCORE_URLS = 'http://localhost:5099'
    Remove-Item env:ConnectionStrings__DefaultConnection -ErrorAction SilentlyContinue
    $erro = Join-Path $Tmp 'prod-sem-cs.err.log'
    $p = Start-Process -FilePath $exe -WorkingDirectory $Web -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $Tmp 'prod-sem-cs.log') -RedirectStandardError $erro
    $null = $p.Handle      # mantém o handle para ler o ExitCode depois
    if (-not $p.WaitForExit(20000)) { Stop-Process -Id $p.Id -Force; Write-Host 'A aplicação NÃO falhou como esperado.' -ForegroundColor Red }
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    Write-Host "Código de saída do processo: $($p.ExitCode)" -ForegroundColor Yellow
    Get-Content $erro -Encoding Oem | Select-Object -First 6 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Capturar 'Fig_8_4'

    # ---------------------------------------------------------------- Fig. 8.2 / 8.3 – Docker
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) { & docker info *> $null }
    if (-not $docker -or $LASTEXITCODE -ne 0) {
        Write-Host "`nDocker não encontrado ou parado. Abra o Docker Desktop e rode de novo este script para gerar as Fig. 8.2 e 8.3." -ForegroundColor Yellow
    } else {
        Figura 'Fig_8_2' 'docker build e docker run com variáveis externas; nenhum segredo na imagem (history e inspect)'
        [void](Executar 'docker' @('build', '-t', 'portaltarefas:local', $Raiz) -UltimasLinhas 6)
        & docker rm -f portaltarefas *> $null
        Write-Host 'PS> docker run -d --name portaltarefas -p 8080:8080 -e ConnectionStrings__DefaultConnection="Server=sem-banco" portaltarefas:local' -ForegroundColor Gray
        & docker run -d --name portaltarefas -p 8080:8080 -e 'ConnectionStrings__DefaultConnection=Server=sem-banco' portaltarefas:local | Out-Null
        & docker ps --filter name=portaltarefas --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | Write-Host
        Passo 'docker history (camadas): procura por segredos'
        $hist = & docker history --no-trunc --format '{{.CreatedBy}}' portaltarefas:local
        foreach ($termo in @('Password', 'Senha', 'ConnectionStrings__', 'MSSQL_SA_PASSWORD')) {
            $n = @($hist | Where-Object { $_ -match $termo }).Count
            Write-Host ("  '{0}' nas camadas: {1}" -f $termo, $n) -ForegroundColor $(if ($n -eq 0) { 'Green' } else { 'Red' })
        }
        Passo 'docker image inspect: variáveis de ambiente gravadas na imagem'
        (& docker image inspect --format '{{json .Config.Env}}' portaltarefas:local | ConvertFrom-Json) | ForEach-Object { Write-Host "  $_" }
        Passo 'Usuário do contêiner (não root)'
        Write-Host ("  " + (& docker exec portaltarefas id))
        Capturar 'Fig_8_2'

        Figura 'Fig_8_3' 'curl http://localhost:8080/health/live: 200 Healthy'
        for ($i = 0; $i -lt 30; $i++) { if ((& curl.exe -s -o NUL -w '%{http_code}' 'http://localhost:8080/health/live') -eq '200') { break }; Start-Sleep 1 }
        Write-Host 'PS> curl.exe -i http://localhost:8080/health/live' -ForegroundColor Gray
        & curl.exe -s -i 'http://localhost:8080/health/live' | ForEach-Object { Write-Host "  $_" }
        Passo 'Estado do HEALTHCHECK do Docker'
        Start-Sleep 3
        & docker ps --filter name=portaltarefas --format 'table {{.Names}}\t{{.Status}}' | Write-Host
        Capturar 'Fig_8_3'
    }

    Write-Host ""; Ok 'Relatório 8 (parte local) concluído. Fig. 8.5 e 8.6 são no GitHub Actions (veja o LEIA-ME).'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem (e evidencias\_tmp\ultimo-erro.txt, se existir) para o Claude.' -ForegroundColor Red }
finally { Parar-Api }
