using System.Diagnostics;

namespace PortalTarefas.Web.Middlewares;

public class RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
{
    private const string Cabecalho = "X-Correlation-ID";

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = ObterOuCriarCorrelationId(context);
        context.Response.OnStarting(() =>
        {
            context.Response.Headers[Cabecalho] = correlationId;
            return Task.CompletedTask;
        });

        using var escopo = logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId });
        logger.LogInformation("→ Entrada: {Metodo} {Caminho}", context.Request.Method, context.Request.Path);

        var cronometro = Stopwatch.StartNew();
        var falhou = false;
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            falhou = true;
            logger.LogError(ex, "Exceção não tratada em {Metodo} {Caminho}", context.Request.Method, context.Request.Path);
            throw; // o UseExceptionHandler responde ao cliente
        }
        finally
        {
            cronometro.Stop();
            var status = falhou ? StatusCodes.Status500InternalServerError : context.Response.StatusCode;
            logger.LogInformation("← Saída: {Metodo} {Caminho} => {Status} em {Duracao} ms",
                context.Request.Method, context.Request.Path, status, cronometro.ElapsedMilliseconds);
        }
    }

    // Relatório 7: a correlação passa a ser o TraceId da requisição (W3C), o mesmo do traceId do Problem Details
    private static string ObterOuCriarCorrelationId(HttpContext context)
        => Activity.Current?.TraceId.ToString() ?? Guid.NewGuid().ToString("N");
}

public static class RequestLoggingMiddlewareExtensions
{
    public static IApplicationBuilder UseRequestLogging(this IApplicationBuilder app)
        => app.UseMiddleware<RequestLoggingMiddleware>();
}
