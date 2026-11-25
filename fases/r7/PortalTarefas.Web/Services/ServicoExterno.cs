using Polly.CircuitBreaker;

namespace PortalTarefas.Web.Services;

public class ServicoExterno(HttpClient http, ILogger<ServicoExterno> logger)
{
    public async Task<IResult> ChamarAsync(string caminho, CancellationToken ct)
    {
        try
        {
            var resposta = await http.GetAsync(caminho, ct);
            resposta.EnsureSuccessStatusCode();
            logger.LogInformation("Dependência respondeu com sucesso em {Caminho}", caminho);
            return Results.Ok(new { ok = true });
        }
        catch (BrokenCircuitException)
        {
            logger.LogWarning("Circuito aberto para {Caminho}", caminho);
            return Results.Problem(statusCode: 503, title: "Dependência temporariamente indisponível.");
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning("Falha na dependência {Caminho}: {Status}", caminho, ex.StatusCode);
            return Results.Problem(statusCode: 502, title: "Falha na dependência externa.");
        }
    }
}
