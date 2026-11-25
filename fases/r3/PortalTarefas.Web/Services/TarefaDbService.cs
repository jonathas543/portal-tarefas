using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Data;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Services;

public class TarefaDbService(PortalTarefasDbContext db) : ITarefaService
{
    public async Task<IReadOnlyList<Tarefa>> ObterTodasAsync(CancellationToken ct = default)
        => await db.Tarefas.AsNoTracking().OrderBy(t => t.Prazo).ToListAsync(ct);

    public Task<Tarefa?> ObterPorIdAsync(Guid id, CancellationToken ct = default)
        => db.Tarefas.AsNoTracking().FirstOrDefaultAsync(t => t.Id == id, ct);

    public async Task<Tarefa> AdicionarAsync(TarefaInputModel input, CancellationToken ct = default)
    {
        var tarefa = new Tarefa
        {
            Id = Guid.NewGuid(), Titulo = input.Titulo, Descricao = input.Descricao,
            Prioridade = input.Prioridade, Prazo = input.Prazo!.Value.Date
        };
        db.Tarefas.Add(tarefa);
        await db.SaveChangesAsync(ct);
        return tarefa;
    }

    public async Task<Tarefa?> AtualizarAsync(Guid id, TarefaInputModel input, CancellationToken ct = default)
    {
        var tarefa = await db.Tarefas.FirstOrDefaultAsync(t => t.Id == id, ct);
        if (tarefa is null) return null;
        tarefa.Titulo = input.Titulo;
        tarefa.Descricao = input.Descricao;
        tarefa.Prioridade = input.Prioridade;
        tarefa.Prazo = input.Prazo!.Value.Date;
        await db.SaveChangesAsync(ct);
        return tarefa;
    }
}
