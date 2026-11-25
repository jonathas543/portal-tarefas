using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Data;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Services;

public class ConflitoConcorrenciaException(Guid id)
    : Exception($"A tarefa {id} foi modificada por outro usuário. Recarregue e tente novamente.");

public class TarefaTransacaoService(PortalTarefasDbContext db)
{
    public async Task AlterarSituacaoAsync(Guid id, string novaSituacao, byte[] rowVersion,
        bool simularFalhaAposAlteracao = false, CancellationToken ct = default)
    {
        await using var transacao = await db.Database.BeginTransactionAsync(ct);
        try
        {
            var tarefa = await db.Tarefas.FirstOrDefaultAsync(t => t.Id == id, ct)
                         ?? throw new KeyNotFoundException($"Tarefa {id} não encontrada.");

            var anterior = tarefa.Situacao;
            db.Entry(tarefa).Property(t => t.RowVersion).OriginalValue = rowVersion;   // token do cliente
            tarefa.Situacao = novaSituacao;
            await db.SaveChangesAsync(ct);                                             // 1ª gravação

            if (simularFalhaAposAlteracao) throw new InvalidOperationException("Falha simulada (didática).");

            db.Auditorias.Add(new AuditoriaTarefa
            {
                TarefaId = id, Evento = $"Situação: {anterior} -> {novaSituacao}", OcorridoEmUtc = DateTime.UtcNow
            });
            await db.SaveChangesAsync(ct);                                             // 2ª gravação
            await transacao.CommitAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            await transacao.RollbackAsync(ct);
            throw new ConflitoConcorrenciaException(id);
        }
        catch
        {
            await transacao.RollbackAsync(ct);
            throw;
        }
    }
}
