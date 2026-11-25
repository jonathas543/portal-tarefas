using Microsoft.AspNetCore.Mvc;
using PortalTarefas.Web.Filters;
using PortalTarefas.Web.Models;
using PortalTarefas.Web.Services;
using PortalTarefas.Web.ViewModels;

namespace PortalTarefas.Web.Controllers;

[ServiceFilter(typeof(LogActionFilter))]
public class TarefasMvcController(ITarefaService servico) : Controller
{
    public async Task<IActionResult> Index(CancellationToken ct)
        => View((await servico.ObterTodasAsync(ct)).Select(ParaViewModel).ToList());

    public async Task<IActionResult> Details(Guid id, CancellationToken ct)
    {
        var tarefa = await servico.ObterPorIdAsync(id, ct);
        return tarefa is null ? NotFound() : View(ParaViewModel(tarefa));
    }

    [HttpGet]
    public IActionResult Create() => View(new TarefaInputModel { Prazo = DateTime.Today.AddDays(7) });

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(TarefaInputModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid) return View(model);          // preserva os dados digitados
        var criada = await servico.AdicionarAsync(model, ct);
        return RedirectToAction(nameof(Details), new { id = criada.Id });
    }

    [HttpGet]
    public async Task<IActionResult> Edit(Guid id, CancellationToken ct)
    {
        var t = await servico.ObterPorIdAsync(id, ct);
        if (t is null) return NotFound();
        ViewData["Id"] = id;
        return View(new TarefaInputModel
        {
            Titulo = t.Titulo, Descricao = t.Descricao, Prioridade = t.Prioridade, Prazo = t.Prazo
        });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Guid id, TarefaInputModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid) { ViewData["Id"] = id; return View(model); }
        var atualizada = await servico.AtualizarAsync(id, model, ct);
        return atualizada is null ? NotFound() : RedirectToAction(nameof(Details), new { id });
    }

    private static TarefaViewModel ParaViewModel(Tarefa t)
        => new(t.Id, t.Titulo, t.Descricao, t.Prioridade, t.Prazo, t.Situacao);
}
