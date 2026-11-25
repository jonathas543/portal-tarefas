using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Data;
using PortalTarefas.Web.Dtos;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Services;

public class TarefasApiService(PortalTarefasDbContext db)
{
    public async Task<PaginaDto<TarefaResumoDto>> ListarAsync(TarefaConsulta c, CancellationToken ct)
    {
        var query = db.Tarefas.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(c.Situacao)) query = query.Where(t => t.Situacao == c.Situacao);
        if (c.Prioridade is not null) query = query.Where(t => t.Prioridade == c.Prioridade);
        if (!string.IsNullOrWhiteSpace(c.Busca)) query = query.Where(t => t.Titulo.Contains(c.Busca));
        if (c.PrazoAte is not null) query = query.Where(t => t.Prazo <= c.PrazoAte.Value.Date);

        var total = await query.CountAsync(ct);
        var desc = c.Direcao == "desc";

        IOrderedQueryable<Tarefa> ordenada = (c.OrdenarPor, desc) switch
        {
            ("prazo", true) => query.OrderByDescending(t => t.Prazo),
            ("prazo", false) => query.OrderBy(t => t.Prazo),
            ("situacao", true) => query.OrderByDescending(t => t.Situacao),
            ("situacao", false) => query.OrderBy(t => t.Situacao),
            (_, true) => query.OrderByDescending(t => t.Titulo),
            _ => query.OrderBy(t => t.Titulo)
        };

        var itens = await ordenada.ThenBy(t => t.Id)
            .Skip((c.Pagina - 1) * c.Tamanho).Take(c.Tamanho)
            .Select(t => new TarefaResumoDto(t.Id, t.Titulo, t.Prioridade, t.Prazo, t.Situacao))
            .ToListAsync(ct);

        return new PaginaDto<TarefaResumoDto>(itens, c.Pagina, c.Tamanho, total,
            (int)Math.Ceiling(total / (double)c.Tamanho));
    }

    public async Task<TarefaDetalhesDto?> ObterAsync(Guid id, CancellationToken ct)
    {
        var t = await db.Tarefas.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct);
        return t is null ? null : Mapear(t);
    }

    public async Task<TarefaDetalhesDto> CriarAsync(TarefaCriarDto dto, CancellationToken ct)
    {
        var t = new Tarefa
        {
            Id = Guid.NewGuid(), Titulo = dto.Titulo.Trim(), Descricao = dto.Descricao,
            Prioridade = dto.Prioridade, Prazo = dto.Prazo!.Value.Date
        };
        db.Tarefas.Add(t);
        await db.SaveChangesAsync(ct);
        return Mapear(t);
    }

    public async Task<TarefaDetalhesDto?> AtualizarAsync(Guid id, TarefaAtualizarDto dto, CancellationToken ct)
    {
        var t = await db.Tarefas.FirstOrDefaultAsync(x => x.Id == id, ct);
        if (t is null) return null;

        db.Entry(t).Property(x => x.RowVersion).OriginalValue = dto.RowVersion;
        t.Titulo = dto.Titulo.Trim();
        t.Descricao = dto.Descricao;
        t.Prioridade = dto.Prioridade;
        t.Prazo = dto.Prazo!.Value.Date;
        t.Situacao = dto.Situacao;

        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { throw new ConflitoConcorrenciaException(id); }
        return Mapear(t);
    }

    public async Task<bool> ExcluirAsync(Guid id, CancellationToken ct)
    {
        var t = await db.Tarefas.FirstOrDefaultAsync(x => x.Id == id, ct);
        if (t is null) return false;
        db.Tarefas.Remove(t);
        await db.SaveChangesAsync(ct);
        return true;
    }

    private static TarefaDetalhesDto Mapear(Tarefa t)
        => new(t.Id, t.Titulo, t.Descricao, t.Prioridade, t.Prazo, t.Situacao, t.RowVersion);
}
