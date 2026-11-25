using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Data;
using PortalTarefas.Web.Services;
using Xunit;

namespace PortalTarefas.Tests;

[Trait("Category", "Integracao")]
public class ConcorrenciaTests : IAsyncLifetime
{
    // Servidor do teste: variável PORTALTAREFAS_TEST_SERVER (padrão: LocalDB)
    private static readonly string Servidor =
        Environment.GetEnvironmentVariable("PORTALTAREFAS_TEST_SERVER") ?? "(localdb)\\MSSQLLocalDB";

    private readonly string _cs =
        $"Server={Servidor};Database=PortalTarefasTeste_{Guid.NewGuid():N};Trusted_Connection=True;TrustServerCertificate=True";

    private PortalTarefasDbContext NovoContexto() => new(
        new DbContextOptionsBuilder<PortalTarefasDbContext>().UseSqlServer(_cs).Options);

    public async Task InitializeAsync()
    {
        await using var db = NovoContexto();
        await db.Database.MigrateAsync();
        await DbSeeder.SeedAsync(db);
    }

    public async Task DisposeAsync()
    {
        await using var db = NovoContexto();
        await db.Database.EnsureDeletedAsync();
    }

    [Fact]
    public async Task Duas_edicoes_da_mesma_tarefa_geram_conflito()
    {
        await using var sessaoA = NovoContexto();
        await using var sessaoB = NovoContexto();
        var id = DbSeeder.TarefaSeedId;

        var lidaPorA = await sessaoA.Tarefas.AsNoTracking().SingleAsync(t => t.Id == id);
        var lidaPorB = await sessaoB.Tarefas.AsNoTracking().SingleAsync(t => t.Id == id);

        await new TarefaTransacaoService(sessaoA).AlterarSituacaoAsync(id, "EmAndamento", lidaPorA.RowVersion);

        await Assert.ThrowsAsync<ConflitoConcorrenciaException>(() =>
            new TarefaTransacaoService(sessaoB).AlterarSituacaoAsync(id, "Concluida", lidaPorB.RowVersion));
    }

    [Fact]
    public async Task Alteracao_com_sucesso_grava_situacao_e_auditoria()
    {
        await using var db = NovoContexto();
        var id = DbSeeder.TarefaSeedId;
        var lida = await db.Tarefas.AsNoTracking().SingleAsync(t => t.Id == id);

        await new TarefaTransacaoService(db).AlterarSituacaoAsync(id, "EmAndamento", lida.RowVersion);

        await using var conferencia = NovoContexto();
        Assert.Equal("EmAndamento", (await conferencia.Tarefas.AsNoTracking().SingleAsync(t => t.Id == id)).Situacao);
        Assert.Single(await conferencia.Auditorias.ToListAsync());
    }

    [Fact]
    public async Task Falha_apos_alteracao_provoca_rollback()
    {
        await using var db = NovoContexto();
        var id = DbSeeder.TarefaSeedId;
        var original = await db.Tarefas.AsNoTracking().SingleAsync(t => t.Id == id);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            new TarefaTransacaoService(db).AlterarSituacaoAsync(id, "Concluida", original.RowVersion,
                simularFalhaAposAlteracao: true));

        await using var conferencia = NovoContexto();
        Assert.Equal("Pendente", (await conferencia.Tarefas.AsNoTracking().SingleAsync(t => t.Id == id)).Situacao);
        Assert.Empty(await conferencia.Auditorias.ToListAsync());
    }
}
