using Microsoft.AspNetCore.Mvc;
using PortalTarefas.Web.Services;
using PortalTarefas.Web.ViewModels;

namespace PortalTarefas.Web.Components;

public class TarefasVencidasViewComponent(ITarefaService servico) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync(int maximo = 5)
    {
        var vencidas = (await servico.ObterTodasAsync())
            .Select(t => new TarefaViewModel(t.Id, t.Titulo, t.Descricao, t.Prioridade, t.Prazo, t.Situacao))
            .Where(t => t.Vencida)
            .Take(maximo)
            .ToList();
        return View(vencidas);
    }
}
