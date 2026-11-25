# Relatório 5 – telas do navegador totalmente automatizadas (Playwright + Edge instalado)
# Uso:  powershell -ExecutionPolicy Bypass -File .\scripts\r5-auto.ps1
. "$PSScriptRoot\_comum.ps1"

$viteProc = $null
function Instalar-Playwright {
    $nav = Join-Path $PSScriptRoot '.nav'
    if (-not (Test-Path (Join-Path $nav 'node_modules\playwright-core'))) {
        Passo 'Instalando o playwright-core (usa o Chrome já instalado; não baixa navegador)'
        New-Item -ItemType Directory -Force $nav | Out-Null
        if (-not (Test-Path (Join-Path $nav 'package.json'))) { '{ "private": true }' | Set-Content (Join-Path $nav 'package.json') -Encoding ASCII }
        [void](Executar 'npm.cmd' @('install', '--prefix', $nav, 'playwright-core@1', '--no-fund', '--no-audit') -UltimasLinhas 2)
    }
}
function Navegador([string]$Cenario) {
    & node (Join-Path $PSScriptRoot 'navegador.mjs') $Cenario
    if ($LASTEXITCODE -ne 0) { throw "A automação do navegador falhou no cenário $Cenario." }
}

try {
    Exigir-Fase 'r5'
    Instalar-Playwright
    Aplicar-Fase 'r5'
    Compilar
    Iniciar-Api -NomeLog 'api-r5e'
    $script:viteProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npm run dev' -WorkingDirectory $Front -PassThru -WindowStyle Minimized
    for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 700; if ((& curl.exe -s -o NUL -w '%{http_code}' 'http://localhost:5173/') -eq '200') { break } }
    Ok 'Vite em execução em http://localhost:5173'

    Write-Host 'O Chrome vai abrir e ser controlado sozinho. Não clique em nada até o fim.' -ForegroundColor Cyan
    Navegador 'r5'

    Passo 'Parando a API para o cenário de erro de rede'
    Parar-Api
    Navegador 'r5-erro'
    Iniciar-Api -NomeLog 'api-r5f'

    Figura 'Fig_5_6' 'Troca rápida de filtro com atraso simulado (2 s): a requisição anterior é cancelada (AbortController)'
    Write-Host 'Requisições a /api/tarefas registradas pelo navegador (tempo desde a 1ª troca de filtro):' -ForegroundColor White
    Get-Content (Join-Path $Tmp 'rede-5_6.txt') -Encoding UTF8 | ForEach-Object {
        $cor = if ($_ -match 'CANCELADA') { 'Yellow' } elseif ($_ -match 'concluída') { 'Green' } else { 'Gray' }
        Write-Host "  $_" -ForegroundColor $cor }
    Write-Host ''
    Write-Host 'Leitura: a requisição de situacao=Pendente foi abortada quando o filtro mudou para EmAndamento;' -ForegroundColor DarkGray
    Write-Host 'só a última requisição chega à tela, evitando que uma resposta antiga sobrescreva a nova.' -ForegroundColor DarkGray
    Capturar 'Fig_5_6'

    Write-Host ""; Ok 'Telas do Relatório 5 geradas automaticamente.'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem para o Claude.' -ForegroundColor Red }
finally { if ($script:viteProc) { & taskkill.exe /PID $script:viteProc.Id /T /F *> $null }; Parar-Api }
