using System.Diagnostics;
using Microsoft.AspNetCore.Mvc.Filters;

namespace PortalTarefas.Web.Filters;

public class LogActionFilter(ILogger<LogActionFilter> logger) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var acao = context.ActionDescriptor.DisplayName;
        var cronometro = Stopwatch.StartNew();

        var executada = await next();

        cronometro.Stop();
        var resultado = executada.Exception is not null
            ? "Exceção"
            : executada.Result?.GetType().Name ?? "Sem resultado";
        logger.LogInformation(
            "Ação {Acao} | ModelState válido: {Valido} | Resultado: {Resultado} | {Duracao} ms",
            acao, context.ModelState.IsValid, resultado, cronometro.ElapsedMilliseconds);
    }
}
