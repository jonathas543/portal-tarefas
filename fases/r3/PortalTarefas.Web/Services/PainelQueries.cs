using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Data;

namespace PortalTarefas.Web.Services;

public record PainelItemDto(string Situacao, int Total);

public class PainelQueries(PortalTarefasDbContext db, IConfiguration config)
{
    public async Task<IReadOnlyList<PainelItemDto>> ResumoEfAsync(DateTime ate, CancellationToken ct = default)
        => await db.Tarefas.AsNoTracking()
            .Where(t => t.Prazo <= ate.Date)
            .GroupBy(t => t.Situacao)
            .OrderBy(g => g.Key)
            .Select(g => new PainelItemDto(g.Key, g.Count()))
            .ToListAsync(ct);

    public async Task<IReadOnlyList<PainelItemDto>> ResumoDapperAsync(DateTime ate, CancellationToken ct = default)
    {
        const string sql = """
            SELECT Situacao, COUNT(*) AS Total
            FROM Tarefas
            WHERE Prazo <= @Ate
            GROUP BY Situacao
            ORDER BY Situacao
            """;
        await using var conexao = new SqlConnection(config.GetConnectionString("DefaultConnection"));
        var linhas = await conexao.QueryAsync<PainelItemDto>(
            new CommandDefinition(sql, new { Ate = ate.Date }, cancellationToken: ct));
        return linhas.ToList();
    }
}
