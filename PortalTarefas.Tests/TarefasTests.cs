using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using PortalTarefas.Web.Controllers;
using PortalTarefas.Web.Models;
using PortalTarefas.Web.Services;
using Xunit;

namespace PortalTarefas.Tests;

public class TarefaInputModelTests
{
    private static List<ValidationResult> Validar(TarefaInputModel modelo)
    {
        var erros = new List<ValidationResult>();
        Validator.TryValidateObject(modelo, new ValidationContext(modelo), erros, validateAllProperties: true);
        return erros;
    }

    [Fact]
    public void Titulo_vazio_e_invalido()
        => Assert.Contains(Validar(new TarefaInputModel { Titulo = "", Prazo = DateTime.Today.AddDays(1) }),
                           e => e.MemberNames.Contains("Titulo"));

    [Fact]
    public void Prazo_no_passado_e_invalido()
        => Assert.Contains(Validar(new TarefaInputModel { Titulo = "x", Prazo = DateTime.Today.AddDays(-1) }),
                           e => e.MemberNames.Contains("Prazo"));

    [Fact]
    public void Urgente_com_prazo_distante_e_invalido()
        => Assert.Contains(Validar(new TarefaInputModel
           { Titulo = "x", Prioridade = Prioridade.Urgente, Prazo = DateTime.Today.AddDays(10) }),
           e => e.MemberNames.Contains("Prazo"));

    [Fact]
    public void Modelo_valido_nao_gera_erros()
        => Assert.Empty(Validar(new TarefaInputModel { Titulo = "x", Prazo = DateTime.Today.AddDays(2) }));
}

public class TarefasMvcControllerTests
{
    [Fact]
    public async Task Create_com_modelo_invalido_reexibe_a_view_com_os_dados()
    {
        var controller = new TarefasMvcController(new TarefaMemoriaService());
        controller.ModelState.AddModelError("Titulo", "O título é obrigatório.");
        var modelo = new TarefaInputModel { Descricao = "mantida" };

        var resultado = await controller.Create(modelo, default);

        Assert.Same(modelo, Assert.IsType<ViewResult>(resultado).Model);
    }

    [Fact]
    public async Task Details_com_id_inexistente_retorna_404()
    {
        var controller = new TarefasMvcController(new TarefaMemoriaService());
        Assert.IsType<NotFoundResult>(await controller.Details(Guid.NewGuid(), default));
    }
}
