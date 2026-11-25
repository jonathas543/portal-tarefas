# Relatório 5 – Front-end React + TypeScript (Vite) consumindo a API
# Uso:  .\scripts\r5.ps1
. "$PSScriptRoot\_comum.ps1"

$viteProc = $null
function Iniciar-Vite {
    $script:viteProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npm run dev' -WorkingDirectory $Front -PassThru -WindowStyle Minimized
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 700
        $c = & curl.exe -s -o NUL -w '%{http_code}' 'http://localhost:5173/'
        if ($c -eq '200') { Ok 'Vite em execução em http://localhost:5173'; return }
    }
    throw 'O servidor do Vite não respondeu em http://localhost:5173.'
}
function Parar-Vite {
    if ($script:viteProc) { & taskkill.exe /PID $script:viteProc.Id /T /F *> $null; $script:viteProc = $null }
}

try {
    Exigir-Fase 'r4'
    Verificar-Ferramentas -Node
    Aplicar-Fase 'r5'

    Passo 'Instalando as dependências do front-end (npm install)'
    Push-Location $Front
    try { [void](Executar 'npm.cmd' @('install', '--no-fund', '--no-audit') -UltimasLinhas 5) } finally { Pop-Location }

    # ---------------------------------------------------------------- Fig. 5.7 – build de produção
    Figura 'Fig_5_7' 'npm run build: verificação de tipos (tsc) e build do Vite sem erros'
    Push-Location $Front
    try { [void](Executar 'npm.cmd' @('run', 'build') -UltimasLinhas 22) } finally { Pop-Location }
    Capturar 'Fig_5_7'

    Compilar
    Iniciar-Api -NomeLog 'api-r5'
    Iniciar-Vite

    Clear-Host
    Write-Host 'Telas do navegador (React). Para cada uma, prepare a tela e pressione Enter.' -ForegroundColor Cyan
    Write-Host 'O print é tirado da janela que estiver na frente depois da contagem.' -ForegroundColor Cyan
    Start-Process 'http://localhost:5173/tarefas'

    CapturaAssistida 'Fig_5_1' 'Lista aberta em http://localhost:5173/tarefas mostrando as tarefas (para "Carregando…", use F12 > Network > Slow 3G e recarregue).'
    CapturaAssistida 'Fig_5_1b' 'Lista vazia: escolha um filtro sem resultados (ex.: Situação = Concluída) até aparecer "Nenhuma tarefa encontrada."'

    Passo 'Parando a API para o cenário de erro de rede'
    Parar-Api
    CapturaAssistida 'Fig_5_2' 'API parada: recarregue a lista (F5). Deve aparecer a mensagem de erro, e não "Carregando…" para sempre.'
    Iniciar-Api -NomeLog 'api-r5b'
    CapturaAssistida 'Fig_5_2b' 'Erro 400 da API: acesse http://localhost:5173/tarefas?ordenarPor=id (mensagem derivada do Problem Details).'

    CapturaAssistida 'Fig_5_3' 'Acesso direto: abra http://localhost:5173/tarefas/7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b03 (detalhes da tarefa).'
    CapturaAssistida 'Fig_5_3b' 'Id inexistente: abra http://localhost:5173/tarefas/00000000-0000-0000-0000-000000000001 ("Tarefa não encontrada.").'
    CapturaAssistida 'Fig_5_4' 'Filtro e página na URL: volte à lista, escolha Situação = Pendente e recarregue (F5). A URL mostra ?situacao=Pendente&pagina=1 e o filtro se mantém.'
    CapturaAssistida 'Fig_5_5' 'Cadastro inválido: em "Nova tarefa", clique em Salvar com o título vazio (erros por campo).'
    CapturaAssistida 'Fig_5_5b' 'Cadastro válido: preencha título e prazo futuro e salve. A tela de detalhes abre sem recarregar a página.'
    CapturaAssistida 'Fig_5_6' 'Cancelamento: F12 > Network > Slow 3G; troque o filtro de Situação rapidamente duas vezes. A aba Network mostra a requisição anterior como (canceled).'

    Write-Host ""; Ok 'Relatório 5 concluído. Prints em .\evidencias'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem (e evidencias\_tmp\ultimo-erro.txt, se existir) para o Claude.' -ForegroundColor Red }
finally { Parar-Vite; Parar-Api }
