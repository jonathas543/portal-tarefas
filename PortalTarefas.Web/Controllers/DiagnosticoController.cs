using Microsoft.AspNetCore.Mvc;

namespace PortalTarefas.Web.Controllers;

[ApiController]
[Route("api/diagnostico-mvc")]
public class DiagnosticoController : ControllerBase
{
    [HttpGet("ping")]
    public IActionResult Ping() => Ok(new { status = "ok", origem = "controller-mvc", horaUtc = DateTime.UtcNow });
}
