# Relatório 7 – Observabilidade, Health Checks, resiliência, rate limiting e output caching
# Uso:  .\scripts\r7.ps1   (leva cerca de 4 minutos por causa das janelas de 1 minuto do rate limiting)
. "$PSScriptRoot\_comum.ps1"

function Aguardar-Janela([int]$Segundos = 62) {
    Write-Host "  aguardando $Segundos s para abrir uma nova janela do rate limiting..." -ForegroundColor DarkGray
    Start-Sleep $Segundos
}

try {
    Exigir-Fase 'r6'
    Verificar-Ferramentas
    Aplicar-Fase 'r7'
    $s = Senhas-Dev
    Compilar
    Iniciar-Api -NomeLog 'api-r7'      # RateLimit:Requisicoes = 5 (appsettings.Development.json)
    $jarAdmin = Join-Path $Tmp 'admin7.txt'

    # ---------------------------------------------------------------- Fig. 7.1 – erro localizado pelo TraceId
    Figura 'Fig_7_1' 'Erro provocado e localizado nos logs pelo TraceId (sem senha, cookie ou connection string)'
    $r = Http -Url '/api/diagnostico/erro' -MaxLinhas 9
    $traceId = ($r.Json.traceId -split '-')[1]
    Passo "Busca do TraceId $traceId no log estruturado (JSON)"
    Start-Sleep 1
    LogApi | Where-Object { $_ -match $traceId -and $_ -match '"LogLevel":"(Error|Information)"' } | Select-Object -First 3 | ForEach-Object {
        $l = $_ | ConvertFrom-Json
        $escopo = ($l.Scopes | Where-Object { $_.CorrelationId } | Select-Object -First 1).CorrelationId
        Write-Host ("  [{0}] {1} | {2} | CorrelationId={3}" -f $l.LogLevel, $l.Category, $l.Message, $escopo) -ForegroundColor DarkGray
    }
    $log = (LogApi) -join "`n"
    Passo 'Dados sensíveis no log'
    foreach ($par in @(@('Senha do administrador', $s.Admin), @('Senha do usuário', $s.Usuario), @('Connection string', 'Trusted_Connection'), @('Cookie de sessão', 'portaltarefas.auth='))) {
        $n = ([regex]::Matches($log, [regex]::Escape($par[1]))).Count
        Write-Host ("  {0,-24} ocorrências: {1}" -f $par[0], $n) -ForegroundColor $(if ($n -eq 0) { 'Green' } else { 'Red' })
    }
    Capturar 'Fig_7_1'

    # ---------------------------------------------------------------- Fig. 7.2 – trace e métricas
    Figura 'Fig_7_2' 'Uma requisição com o exportador de console: spans de ASP.NET Core, SQL e Tarefas.Criar; métricas'
    [void](Login 'admin@portal.local' $s.Admin $jarAdmin)
    $criada = Http -Metodo POST -Url '/api/tarefas' -Corpo '{"titulo":"Tarefa observada","prioridade":"Urgente","prazo":"2026-11-27"}' -Cookies $jarAdmin -MaxLinhas 0
    [void](Http -Url '/api/tarefas?tamanho=5' -Cookies $jarAdmin -MaxLinhas 0)      # alimenta a métrica de duração da listagem
    Write-Host '  aguardando a exportação periódica das métricas (10 s)...' -ForegroundColor DarkGray
    Start-Sleep 12
    $linhas = LogApi
    $alvoTrace = $null
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        if ($linhas[$i] -match 'Activity.DisplayName:\s+Tarefas.Criar') {
            for ($j = $i; $j -ge [Math]::Max(0, $i - 4); $j--) { if ($linhas[$j] -match 'Activity.TraceId:\s+(\w+)') { $alvoTrace = $Matches[1]; break } }
        }
    }
    Passo "Spans do trace $alvoTrace"
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        if ($alvoTrace -and $linhas[$i] -match "Activity.TraceId:\s+$alvoTrace") {
            $nome = ''; $fonte = ''; $dur = ''
            for ($j = $i + 1; $j -lt [Math]::Min($linhas.Count, $i + 40); $j++) {
                if ($linhas[$j] -match 'Activity.TraceId:') { break }
                if ($linhas[$j] -match 'Activity.DisplayName:\s+(.+)$') { $nome = $Matches[1].Trim() }
                if ($linhas[$j] -match 'Activity.Duration:\s+(.+)$') { $dur = $Matches[1].Trim() }
                if ($linhas[$j] -match 'Instrumentation scope|ActivitySource' -and $j + 1 -lt $linhas.Count -and $linhas[$j + 1] -match 'Name:\s+(.+)$') { $fonte = $Matches[1].Trim() }
            }
            Write-Host ("  span: {0,-34} fonte: {1,-40} duração: {2}" -f $nome, $fonte, $dur)
        }
    }
    Passo 'Métricas de negócio e técnica (última exportação)'
    foreach ($m in @('tarefas.criadas', 'tarefas.consulta.duracao')) {
        $k = -1; for ($i = $linhas.Count - 1; $i -ge 0; $i--) { if ($linhas[$i] -match "Metric Name:\s+$([regex]::Escape($m))") { $k = $i; break } }
        if ($k -ge 0) { $linhas[$k..([Math]::Min($linhas.Count - 1, $k + 5))] | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
        else { Write-Host "  $m ainda não exportada" -ForegroundColor DarkYellow }
    }
    Capturar 'Fig_7_2'

    # ---------------------------------------------------------------- Fig. 7.3 – health checks com o banco parado
    Figura 'Fig_7_3' 'Banco indisponível: /health/ready 503 e /health/live 200'
    Passo 'Com o banco disponível'
    Write-Host ("  /health/live = " + (StatusHttp GET '/health/live') + "    /health/ready = " + (StatusHttp GET '/health/ready'))
    Passo "Parando o banco: ALTER DATABASE [$Banco] SET OFFLINE"
    [void](Sql "ALTER DATABASE [$Banco] SET OFFLINE WITH ROLLBACK IMMEDIATE" $CsMaster)
    try {
        [void](Http -Url '/health/ready' -MaxLinhas 2)
        [void](Http -Url '/health/live' -MaxLinhas 2)
    } finally {
        Passo "Religando o banco: ALTER DATABASE [$Banco] SET ONLINE"
        [void](Sql "ALTER DATABASE [$Banco] SET ONLINE" $CsMaster)
    }
    Start-Sleep 2
    Write-Host ("  /health/ready após religar = " + (StatusHttp GET '/health/ready'))
    Capturar 'Fig_7_3'

    # ---------------------------------------------------------------- Fig. 7.4 – retry
    Figura 'Fig_7_4' 'GET /api/externo/instavel: falha nas duas primeiras chamadas e sucesso na 3ª (retry), visível nos logs'
    $antes = (LogApi).Count
    [void](Http -Url '/api/externo/instavel' -MaxLinhas 4)
    Start-Sleep 1
    Passo 'Tentativas registradas pelo pipeline de resiliência (Polly) e pelo serviço'
    LogApi | Select-Object -Skip $antes | Where-Object { $_ -match '"Category":"(PortalTarefas[^"]*|Polly)"' -and $_ -match 'instavel|Execution attempt|Depend' } | ForEach-Object {
        try { $l = $_ | ConvertFrom-Json; $msg = $l.Message } catch { $msg = $_ }
        if ($msg.Length -gt 170) { $msg = $msg.Substring(0, 170) + '...' }
        Write-Host "  $msg" -ForegroundColor DarkGray
    }
    Capturar 'Fig_7_4'

    # ---------------------------------------------------------------- Fig. 7.5 – circuit breaker
    Figura 'Fig_7_5' 'GET /api/externo/fora repetido: após o limiar, circuito aberto e 503 imediato'
    for ($i = 1; $i -le 8; $i++) {
        $saida = & curl.exe -k -s -o NUL -w '%{http_code} %{time_total}' "$ApiHttps/api/externo/fora"
        $p = $saida -split ' '
        Write-Host ("  chamada {0}: HTTP {1}  em {2:N3} s" -f $i, $p[0], [double]::Parse($p[1], [Globalization.CultureInfo]::InvariantCulture))
    }
    Passo 'Log do serviço'
    LogApi | Where-Object { $_ -match 'Circuito aberto|Falha na depend' } | Select-Object -Last 4 | ForEach-Object {
        try { Write-Host ("  " + ($_ | ConvertFrom-Json).Message) -ForegroundColor DarkGray } catch {} }
    Capturar 'Fig_7_5'

    # ---------------------------------------------------------------- Fig. 7.7 – output caching e invalidação
    Aguardar-Janela
    Figura 'Fig_7_7' 'Endpoint público com cache: mesmo geradoEm nas duas chamadas; novo valor após criar tarefa'
    $c1 = Http -Url '/api/publico/estatisticas' -Silencioso; Write-Host "  1ª chamada: HTTP $($c1.Status)  geradoEm = $($c1.Json.geradoEm)"
    Start-Sleep 2
    $c2 = Http -Url '/api/publico/estatisticas' -Silencioso; Write-Host "  2ª chamada: HTTP $($c2.Status)  geradoEm = $($c2.Json.geradoEm)   (mesmo valor = resposta do cache: $($c1.Json.geradoEm -eq $c2.Json.geradoEm))"
    Passo 'Criando uma tarefa (o controller invalida a tag "publico")'
    [void](Http -Metodo POST -Url '/api/tarefas' -Corpo '{"titulo":"Tarefa que invalida o cache","prioridade":"Normal","prazo":"2026-12-15"}' -Cookies $jarAdmin -MaxLinhas 0)
    $c3 = Http -Url '/api/publico/estatisticas' -Silencioso; Write-Host "  3ª chamada: HTTP $($c3.Status)  geradoEm = $($c3.Json.geradoEm)   (novo valor: $($c3.Json.geradoEm -ne $c2.Json.geradoEm))"
    $c3.Json.porSituacao | Format-Table -AutoSize | Out-String | Write-Host
    Capturar 'Fig_7_7'

    # ---------------------------------------------------------------- Fig. 7.6 – rate limiting
    Aguardar-Janela
    Figura 'Fig_7_6' 'Mais requisições que o limite (5 por minuto): as excedentes recebem 429'
    for ($i = 1; $i -le 8; $i++) {
        $r = Http -Url '/api/publico/estatisticas' -Silencioso
        $ra = ($r.Cabecalhos | Where-Object { $_ -like 'Retry-After:*' }) -replace 'Retry-After:\s*', ''
        $cor = if ($r.Status -eq 429) { 'Yellow' } else { 'Green' }
        Write-Host ("  requisição {0}: HTTP {1}{2}" -f $i, $r.Status, $(if ($ra) { "  Retry-After: $ra" } else { '' })) -ForegroundColor $cor
    }
    Passo 'Log do rate limiting'
    LogApi | Where-Object { $_ -match 'Limite excedido' } | Select-Object -Last 3 | ForEach-Object {
        try { Write-Host ("  " + ($_ | ConvertFrom-Json).Message) -ForegroundColor DarkGray } catch {} }
    Capturar 'Fig_7_6'

    Write-Host ""; Ok 'Relatório 7 concluído. Prints em .\evidencias'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem (e evidencias\_tmp\ultimo-erro.txt, se existir) para o Claude.' -ForegroundColor Red }
finally {
    try { [void](Sql "IF DATABASEPROPERTYEX('$Banco','Status') <> 'ONLINE' ALTER DATABASE [$Banco] SET ONLINE" $CsMaster) } catch {}
    Parar-Api
}
