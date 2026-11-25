using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Data;

public static class DbSeeder
{
    public static readonly Guid TarefaSeedId = Guid.Parse("7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b01");

    public static async Task SeedAsync(PortalTarefasDbContext db, CancellationToken ct = default)
    {
        var seeds = new[]
        {
            new Tarefa { Id = TarefaSeedId, Titulo = "Configurar o ambiente .NET 10",
                         Prioridade = Prioridade.Normal, Prazo = new DateTime(2026, 12, 1) },
            new Tarefa { Id = Guid.Parse("7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b02"), Titulo = "Criar a API de tarefas",
                         Prioridade = Prioridade.Urgente, Prazo = new DateTime(2026, 12, 3) },
            new Tarefa { Id = Guid.Parse("7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b03"), Titulo = "Documentar o contrato OpenAPI",
                         Prioridade = Prioridade.Baixa, Prazo = new DateTime(2026, 12, 10) }
        };

        var ids = seeds.Select(s => s.Id).ToArray();
        var existentes = await db.Tarefas.Where(t => ids.Contains(t.Id)).Select(t => t.Id).ToListAsync(ct);

        db.Tarefas.AddRange(seeds.Where(s => !existentes.Contains(s.Id)));   // idempotente
        await db.SaveChangesAsync(ct);
    }
}
