# Refaz as telas 5.1b, 5.2 e 5.6 do Relatório 5
# Uso:  powershell -ExecutionPolicy Bypass -File .\scripts\r5-refazer.ps1
. "$PSScriptRoot\_comum.ps1"

$viteProc = $null
try {
    Exigir-Fase 'r5'
    Aplicar-Fase 'r5'          # inclui a correção da mensagem de erro de rede (apiClient.ts)
    Compilar
    Iniciar-Api -NomeLog 'api-r5c'
    $script:viteProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npm run dev' -WorkingDirectory $Front -PassThru -WindowStyle Minimized
    for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 700; if ((& curl.exe -s -o NUL -w '%{http_code}' 'http://localhost:5173/') -eq '200') { break } }
    Ok 'Vite em execução em http://localhost:5173'
    Start-Process 'http://localhost:5173/tarefas?situacao=Concluida&pagina=1'

    CapturaAssistida 'Fig_5_1b' 'No navegador deve estar a LISTA com Situação = Concluída e a frase "Nenhuma tarefa encontrada." (endereço localhost:5173/tarefas?situacao=Concluida). Se precisar, recarregue (F5).'

    Passo 'Parando a API para o cenário de erro de rede'
    Parar-Api
    CapturaAssistida 'Fig_5_2' 'API parada: no navegador, mude Situação para "Todas" (ou aperte F5 na lista). Deve aparecer "Não foi possível contactar o servidor."'
    Iniciar-Api -NomeLog 'api-r5d'

    CapturaAssistida 'Fig_5_6' 'Aperte F12 e abra a aba Network (Rede) com o painel VISÍVEL. Em "No throttling" escolha "Slow 4G/3G". Troque o filtro Situação duas vezes bem rápido (Pendente, depois Todas). Na lista da aba Network a primeira requisição "tarefas?..." deve aparecer como (canceled). Deixe isso visível.' 8
    Write-Host ""; Ok 'Telas refeitas.'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red }
finally { if ($script:viteProc) { & taskkill.exe /PID $script:viteProc.Id /T /F *> $null }; Parar-Api }
