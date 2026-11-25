# Relatório 3 – EF Core, migrations, seed, transações, concorrência e Dapper
# Uso (na pasta da solução, terminal do VS Code maximizado):  .\scripts\r3.ps1
. "$PSScriptRoot\_comum.ps1"

try {
    Verificar-Ferramentas -Ef
    Aplicar-Fase 'r3'
    Configurar-Segredos
    Compilar
    $ef = @('--project', $Web, '--no-build')

    # Recuperação: migration de índice gerada vazia numa execução anterior (build desatualizado) é removida
    $vazia = Get-ChildItem (Join-Path $Web 'Migrations') -Filter '*_AdicionarIndiceSituacaoPrazo.cs' -ErrorAction SilentlyContinue |
             Where-Object { (Get-Content $_.FullName -Raw) -notmatch 'CreateIndex' }
    if ($vazia) {
        Passo 'Removendo a migration AdicionarIndiceSituacaoPrazo vazia (gerada com build desatualizado)'
        [void](Executar 'dotnet' @('ef', 'migrations', 'remove', '--project', $Web) -UltimasLinhas 3)
        Compilar
    }

    # ---------------------------------------------------------------- Fig. 3.7a – migration Inicial
    $temMigrations = Test-Path (Join-Path $Web 'Migrations')
    Figura 'Fig_3_7a' 'Comandos de migration: criação da migration Inicial (sem o índice)'
    if (-not $temMigrations) {
        [void](Executar 'dotnet' (@('ef', 'migrations', 'add', 'Inicial') + $ef) -UltimasLinhas 6)
        Compilar
    } else { Write-Host '(a migration Inicial já existia; reutilizada)' -ForegroundColor DarkGray }
    [void](Executar 'dotnet' (@('ef', 'migrations', 'list') + $ef) -UltimasLinhas 8)
    Passo 'Arquivos gerados em PortalTarefas.Web\Migrations'
    Get-ChildItem (Join-Path $Web 'Migrations') -File | Select-Object Name, Length | Format-Table -AutoSize | Out-String | Write-Host
    Capturar 'Fig_3_7a'

    # ---------------------------------------------------------------- Fig. 3.1 – banco inexistente -> esquema + seed
    Figura 'Fig_3_1' 'Update-Database em banco inexistente: esquema criado e seed inserido'
    Excluir-Banco
    Passo "Banco [$Banco] existe antes do comando? $(Banco-Existe)"
    [void](Executar 'dotnet' (@('ef', 'database', 'update', 'Inicial') + $ef) -UltimasLinhas 4)
    Passo "Banco [$Banco] existe depois? $(Banco-Existe)"
    Iniciar-Api -NomeLog 'api-r3'   # na inicialização: MigrateAsync + DbSeeder (somente Desenvolvimento)
    MostrarSql 'Tabelas criadas' "SELECT TABLE_NAME AS Tabela FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY 1"
    MostrarSql 'Tarefas do seed' "SELECT Id, Titulo, Prioridade, Prazo, Situacao FROM Tarefas ORDER BY Prazo"
    Capturar 'Fig_3_1'

    # ---------------------------------------------------------------- Fig. 3.2 – seed idempotente
    Figura 'Fig_3_2' 'Reiniciar a aplicação duas vezes: a contagem do seed não aumenta'
    for ($i = 1; $i -le 2; $i++) {
        Passo "Reinício $i"
        Iniciar-Api -NomeLog "api-r3-reinicio$i"
        MostrarSql "Contagem após o reinício $i" "SELECT COUNT(*) AS TotalTarefas FROM Tarefas"
    }
    Capturar 'Fig_3_2'

    # ---------------------------------------------------------------- Fig. 3.3 – transação com sucesso
    Figura 'Fig_3_3' 'AlterarSituacaoAsync com sucesso: situação alterada e 1 linha em AuditoriaTarefas'
    $consulta = "SELECT Titulo, Situacao, CONVERT(varchar(20), RowVersion, 1) AS RowVersion FROM Tarefas WHERE Id = '$SeedId'"
    MostrarSql 'ANTES - tarefa' $consulta
    MostrarSql 'ANTES - auditoria' "SELECT COUNT(*) AS LinhasAuditoria FROM Auditorias"
    Passo 'Chamada ao serviço transacional'
    [void](Http -Metodo POST -Url "/api/dev/tarefas/$SeedId/situacao?nova=EmAndamento")
    MostrarSql 'DEPOIS - tarefa' $consulta
    MostrarSql 'DEPOIS - auditoria' "SELECT TarefaId, Evento, OcorridoEmUtc FROM Auditorias"
    Capturar 'Fig_3_3'

    # ---------------------------------------------------------------- Fig. 3.4 – rollback
    Figura 'Fig_3_4' 'Mesma operação com falha simulada: rollback (situação e auditoria inalteradas)'
    MostrarSql 'ANTES - tarefa' $consulta
    MostrarSql 'ANTES - auditoria' "SELECT COUNT(*) AS LinhasAuditoria FROM Auditorias"
    Passo 'Chamada com falha simulada entre as duas gravações (falhar=true)'
    [void](Http -Metodo POST -Url "/api/dev/tarefas/$SeedId/situacao?nova=Concluida&falhar=true" -MaxLinhas 8)
    MostrarSql 'DEPOIS - tarefa (inalterada)' $consulta
    MostrarSql 'DEPOIS - auditoria (inalterada)' "SELECT COUNT(*) AS LinhasAuditoria FROM Auditorias"
    Capturar 'Fig_3_4'

    # ---------------------------------------------------------------- Fig. 3.6 – painel EF x Dapper
    Figura 'Fig_3_6' 'Painel via EF Core e via Dapper: mesmo resultado; SQL gerado pelo EF no log'
    Passo 'EF Core (LINQ GroupBy + AsNoTracking)'
    $rEf = Http -Url '/api/dev/painel/ef?ate=2026-12-31' -MaxLinhas 12
    Passo 'Dapper (SQL explícito e parametrizado)'
    $rDp = Http -Url '/api/dev/painel/dapper?ate=2026-12-31' -MaxLinhas 12
    Passo "Resultados idênticos? $($rEf.Corpo -eq $rDp.Corpo)"
    Passo 'SQL gerado pelo EF Core (log da aplicação)'
    $log = LogApi
    $idx = -1; for ($i = $log.Count - 1; $i -ge 0; $i--) { if ($log[$i] -match 'GROUP BY') { $idx = $i; break } }
    if ($idx -ge 0) { $log[[Math]::Max(0, $idx - 6)..[Math]::Min($log.Count - 1, $idx + 1)] | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
    Capturar 'Fig_3_6'
    Parar-Api

    # ---------------------------------------------------------------- Fig. 3.7b – índice (aprimoramento)
    Figura 'Fig_3_7b' 'Migration AdicionarIndiceSituacaoPrazo: índices da tabela Tarefas antes e depois'
    $indices = "SELECT i.name AS Indice, i.type_desc AS Tipo, STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS Colunas FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id WHERE i.object_id = OBJECT_ID('Tarefas') GROUP BY i.name, i.type_desc"
    MostrarSql 'ANTES' $indices
    Aplicar-Fase 'r3b'
    Compilar
    $lista = (& dotnet ef migrations list --project $Web --no-build 2>$null) -join ' '
    if ($lista -notmatch 'AdicionarIndiceSituacaoPrazo') {
        [void](Executar 'dotnet' (@('ef', 'migrations', 'add', 'AdicionarIndiceSituacaoPrazo') + $ef) -UltimasLinhas 3)
        Compilar
    }
    [void](Executar 'dotnet' (@('ef', 'database', 'update') + $ef) -UltimasLinhas 3)
    MostrarSql 'DEPOIS' $indices
    MostrarSql 'Histórico de migrations aplicadas' "SELECT MigrationId, ProductVersion FROM __EFMigrationsHistory"
    Capturar 'Fig_3_7b'

    # ---------------------------------------------------------------- Fig. 3.5 – concorrência (testes de integração)
    Figura 'Fig_3_5' 'ConcorrenciaTests (bancos isolados): conflito com token antigo, commit e rollback'
    $env:PORTALTAREFAS_TEST_SERVER = $ServidorSql
    [void](Executar 'dotnet' @('test', (Join-Path $Raiz 'PortalTarefas.Tests'), '--no-build', '--filter', 'FullyQualifiedName~ConcorrenciaTests', '--logger', 'console;verbosity=normal') -UltimasLinhas 18 -PermitirFalha)
    Capturar 'Fig_3_5'

    Passo 'Suíte completa de testes (unitários + integração)'
    [void](Executar 'dotnet' @('test', (Join-Path $Raiz 'PortalTarefas.Tests'), '--no-build') -UltimasLinhas 4 -PermitirFalha)
    Write-Host ""; Ok 'Relatório 3 concluído. Prints em .\evidencias'
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Copie esta mensagem (e evidencias\_tmp\ultimo-erro.txt, se existir) para o Claude.' -ForegroundColor Red }
finally { Parar-Api }
