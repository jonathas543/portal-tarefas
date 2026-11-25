using System.Collections.Concurrent;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Services;

public interface ITarefaService
{
    Task<IReadOnlyList<Tarefa>> ObterTodasAsync(CancellationToken ct = default);
    Task<Tarefa?> ObterPorIdAsync(Guid id, CancellationToken ct = default);
    Task<Tarefa> AdicionarAsync(TarefaInputModel input, CancellationToken ct = default);
    Task<Tarefa?> AtualizarAsync(Guid id, TarefaInputModel input, CancellationToken ct = default);
}

public class TarefaMemoriaService : ITarefaService
{
    private readonly ConcurrentDictionary<Guid, Tarefa> _dados = new();

    public Task<IReadOnlyList<Tarefa>> ObterTodasAsync(CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Tarefa>>(_dados.Values.OrderBy(t => t.Prazo).ToList());

    public Task<Tarefa?> ObterPorIdAsync(Guid id, CancellationToken ct = default)
        => Task.FromResult(_dados.GetValueOrDefault(id));

    public Task<Tarefa> AdicionarAsync(TarefaInputModel input, CancellationToken ct = default)
    {
        var tarefa = new Tarefa
        {
            Id = Guid.NewGuid(), Titulo = input.Titulo, Descricao = input.Descricao,
            Prioridade = input.Prioridade, Prazo = input.Prazo!.Value.Date
        };
        _dados[tarefa.Id] = tarefa;
        return Task.FromResult(tarefa);
    }

    public Task<Tarefa?> AtualizarAsync(Guid id, TarefaInputModel input, CancellationToken ct = default)
    {
        if (!_dados.TryGetValue(id, out var tarefa)) return Task.FromResult<Tarefa?>(null);
        tarefa.Titulo = input.Titulo;
        tarefa.Descricao = input.Descricao;
        tarefa.Prioridade = input.Prioridade;
        tarefa.Prazo = input.Prazo!.Value.Date;
        return Task.FromResult<Tarefa?>(tarefa);
    }
}
