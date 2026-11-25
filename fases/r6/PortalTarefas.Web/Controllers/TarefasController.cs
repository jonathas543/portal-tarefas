using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PortalTarefas.Web.Dtos;
using PortalTarefas.Web.Services;

namespace PortalTarefas.Web.Controllers;

[ApiController]
[Route("api/tarefas")]
[Produces("application/json")]
[Authorize]                                         // leitura e criação exigem autenticação
public class TarefasController(TarefasApiService servico) : ControllerBase
{
    [HttpGet]
    [EndpointSummary("Lista tarefas com paginação, filtros e ordenação")]
    [ProducesResponseType<PaginaDto<TarefaResumoDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Listar([FromQuery] TarefaConsulta consulta, CancellationToken ct)
    {
        var pagina = await servico.ListarAsync(consulta, ct);
        Response.Headers["X-Total-Count"] = pagina.Total.ToString();
        return Ok(pagina);
    }

    [HttpGet("{id:guid}", Name = "ObterTarefa")]
    [EndpointSummary("Obtém uma tarefa por identificador")]
    [ProducesResponseType<TarefaDetalhesDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Obter(Guid id, CancellationToken ct)
    {
        var tarefa = await servico.ObterAsync(id, ct);
        return tarefa is null ? NotFound() : Ok(tarefa);
    }

    [HttpPost]
    [EndpointSummary("Cria uma tarefa")]
    [ProducesResponseType<TarefaDetalhesDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Criar([FromBody] TarefaCriarDto dto, CancellationToken ct)
    {
        var criada = await servico.CriarAsync(dto, ct);
        return CreatedAtRoute("ObterTarefa", new { id = criada.Id }, criada);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "EditarOutraEquipe")]       // claim permissao=editar-outra-equipe
    [EndpointSummary("Atualiza uma tarefa (exige o rowVersion lido)")]
    [ProducesResponseType<TarefaDetalhesDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Atualizar(Guid id, [FromBody] TarefaAtualizarDto dto, CancellationToken ct)
    {
        try
        {
            var atualizada = await servico.AtualizarAsync(id, dto, ct);
            return atualizada is null ? NotFound() : Ok(atualizada);
        }
        catch (ConflitoConcorrenciaException)
        {
            return Problem(statusCode: StatusCodes.Status409Conflict, title: "Conflito de concorrência",
                detail: "A tarefa foi modificada por outro usuário. Recarregue e tente novamente.");
        }
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Policy = "SomenteAdmin")]            // role Administrador
    [EndpointSummary("Exclui uma tarefa")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Excluir(Guid id, CancellationToken ct)
        => await servico.ExcluirAsync(id, ct) ? NoContent() : NotFound();
}
