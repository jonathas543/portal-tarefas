# Relatório 4 – API REST: DTOs, paginação, filtros, ordenação, Problem Details, concorrência e OpenAPI
# Uso:  .\scripts\r4.ps1
. "$PSScriptRoot\_comum.ps1"

try {
    Exigir-Fase 'r3'
    Verificar-Ferramentas -Node
    Aplicar-Fase 'r4'
    Compilar
    Iniciar-Api -NomeLog 'api-r4'

    # ---------------------------------------------------------------- Fig. 4.1 – limites de tamanho
    Figura 'Fig_4_1' 'Paginação: tamanho=50 (200) e limites inválidos tamanho=0 / 51 (400 Problem Details)'
    [void](Http -Url '/api/tarefas?tamanho=50' -MaxLinhas 9)
    [void](Http -Url '/api/tarefas?tamanho=0' -MaxLinhas 11)
    [void](Http -Url '/api/tarefas?tamanho=51' -MaxLinhas 4)
    Capturar 'Fig_4_1'

    # ---------------------------------------------------------------- Fig. 4.2 – ordenação
    Figura 'Fig_4_2' 'Ordenação: ordenarPor=prazo&direcao=desc (ordenado) e ordenarPor=id (400)'
    $r = Http -Url '/api/tarefas?ordenarPor=prazo&direcao=desc' -MaxLinhas 0
    $r.Json.itens | Select-Object titulo, prazo, situacao | Format-Table -AutoSize | Out-String | Write-Host
    [void](Http -Url '/api/tarefas?ordenarPor=id' -MaxLinhas 12)
    Capturar 'Fig_4_2'

    # ---------------------------------------------------------------- Fig. 4.3 – filtros combinados
    Figura 'Fig_4_3' 'Filtros combinados: situacao=Pendente&busca=api'
    [void](Http -Url '/api/tarefas?situacao=Pendente&busca=api' -MaxLinhas 20)
    Capturar 'Fig_4_3'

    # ---------------------------------------------------------------- Fig. 4.4 – página além do fim
    Figura 'Fig_4_4' 'GET /api/tarefas?pagina=99: 200 com lista vazia e total correto'
    [void](Http -Url '/api/tarefas?pagina=99' -MaxLinhas 12)
    Capturar 'Fig_4_4'

    # ---------------------------------------------------------------- Fig. 4.5 – 404
    Figura 'Fig_4_5' 'GET /api/tarefas/{inexistente}: 404 em Problem Details'
    [void](Http -Url '/api/tarefas/00000000-0000-0000-0000-000000000001' -MaxLinhas 12)
    Capturar 'Fig_4_5'

    # ---------------------------------------------------------------- Fig. 4.6 – concorrência otimista via HTTP
    Figura 'Fig_4_6' 'Dois PUT com o mesmo rowVersion: 200 e, depois, 409 Problem Details'
    $id = '7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b02'
    $t = Http -Url "/api/tarefas/$id" -MaxLinhas 10
    $corpo = @{ titulo = $t.Json.titulo; descricao = 'Atualizada pelo cliente A'; prioridade = $t.Json.prioridade
                prazo = $t.Json.prazo; situacao = 'EmAndamento'; rowVersion = $t.Json.rowVersion } | ConvertTo-Json -Compress
    Passo "Os dois PUT enviam o mesmo rowVersion lido acima ($($t.Json.rowVersion))"
    [void](Http -Metodo PUT -Url "/api/tarefas/$id" -Corpo $corpo -MaxLinhas 3)
    [void](Http -Metodo PUT -Url "/api/tarefas/$id" -Corpo ($corpo -replace 'cliente A', 'cliente B') -MaxLinhas 9)
    Capturar 'Fig_4_6'

    # ---------------------------------------------------------------- Fig. 4.7 – contrato OpenAPI
    Figura 'Fig_4_7' 'Documento openapi/v1.json (contrato legível sem abrir o código)'
    $dirApi = Join-Path $Raiz 'openapi'; New-Item -ItemType Directory -Force $dirApi | Out-Null
    & curl.exe -k -s "$ApiHttps/openapi/v1.json" -o (Join-Path $dirApi 'v1.json')
    $doc = Get-Content (Join-Path $dirApi 'v1.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "openapi: $($doc.openapi)   título: $($doc.info.title)   versão: $($doc.info.version)" -ForegroundColor White
    Passo 'Operações documentadas'
    foreach ($p in $doc.paths.PSObject.Properties) {
        foreach ($m in $p.Value.PSObject.Properties) {
            $codigos = ($m.Value.responses.PSObject.Properties.Name) -join ', '
            Write-Host ("  {0,-7} {1,-28} {2,-55} respostas: {3}" -f $m.Name.ToUpper(), $p.Name, $m.Value.summary, $codigos)
        }
    }
    Passo 'Parâmetros de consulta de GET /api/tarefas'
    Write-Host ('  ' + (($doc.paths.'/api/tarefas'.get.parameters | ForEach-Object { $_.name }) -join ', '))
    Capturar 'Fig_4_7'

    Start-Process "$ApiHttps/scalar/v1"
    CapturaAssistida 'Fig_4_7b' 'O Scalar foi aberto no navegador (https://localhost:7000/scalar/v1). Expanda GET /api/tarefas para mostrar os parâmetros.'

    # ---------------------------------------------------------------- Fig. 4.8 – evolução compatível do contrato
    Figura 'Fig_4_8' 'Campo opcional prazoAte acrescentado e cliente TypeScript regenerado: diff só com a mudança compatível'
    $cliente = Join-Path $dirApi 'portal-tarefas-api.ts'
    $clienteAnterior = Join-Path $dirApi 'portal-tarefas-api.v1.ts'
    Passo 'Cliente gerado a partir do contrato atual'
    [void](Executar 'npx.cmd' @('-y', 'openapi-typescript', (Join-Path $dirApi 'v1.json'), '-o', $cliente) -UltimasLinhas 2)
    Copy-Item $cliente $clienteAnterior -Force
    Parar-Api
    Aplicar-Fase 'r4b'                      # TarefaConsulta.PrazoAte (opcional) + filtro no serviço
    Compilar
    Iniciar-Api -NomeLog 'api-r4b'
    & curl.exe -k -s "$ApiHttps/openapi/v1.json" -o (Join-Path $dirApi 'v1.json')
    Passo 'Cliente regenerado após a mudança'
    [void](Executar 'npx.cmd' @('-y', 'openapi-typescript', (Join-Path $dirApi 'v1.json'), '-o', $cliente) -UltimasLinhas 2)
    Passo 'Diferença entre o cliente anterior e o novo'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        & git --no-pager diff --no-index --no-color $clienteAnterior $cliente | Select-Object -Skip 2 | ForEach-Object {
            $cor = if ($_ -like '+*') { 'Green' } elseif ($_ -like '-*') { 'Red' } else { 'Gray' }
            Write-Host "  $_" -ForegroundColor $cor }
    } else {
        Compare-Object (Get-Content $clienteAnterior) (Get-Content $cliente) | ForEach-Object { Write-Host "  $($_.SideIndicator) $($_.InputObject)" }
    }
    Passo 'Consumidor antigo continua funcionando (sem o parâmetro novo) e o novo filtro responde:'
    Write-Host ("  sem prazoAte: " + (StatusHttp GET '/api/tarefas') + "   com prazoAte=2026-12-02: " + (Http -Url '/api/tarefas?prazoAte=2026-12-02' -Silencioso).Json.total + " tarefa(s)")
    Capturar 'Fig_4_8'

    Write-Host ""; Ok 'Relatório 4 concluído. Prints em .\evidencias'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem (e evidencias\_tmp\ultimo-erro.txt, se existir) para o Claude.' -ForegroundColor Red }
finally { Parar-Api }
