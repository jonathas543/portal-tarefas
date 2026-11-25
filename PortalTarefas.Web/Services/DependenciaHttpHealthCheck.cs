using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace PortalTarefas.Web.Services;

public class DependenciaHttpHealthCheck(IHttpClientFactory fabrica) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default)
    {
        try
        {
            var resposta = await fabrica.CreateClient("dependencia-saude").GetAsync("/api/diagnostico/ping", ct);
            return resposta.IsSuccessStatusCode ? HealthCheckResult.Healthy() : HealthCheckResult.Unhealthy();
        }
        catch { return HealthCheckResult.Unhealthy("Dependência inacessível."); }   // sem detalhes internos
    }
}
