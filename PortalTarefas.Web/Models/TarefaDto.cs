using System.ComponentModel.DataAnnotations;

namespace PortalTarefas.Web.Models;

public class TarefaDto
{
    public Guid Id { get; set; }

    [Required(ErrorMessage = "O título é obrigatório."), StringLength(100)]
    public string Titulo { get; set; } = string.Empty;

    [StringLength(500)]
    public string? Descricao { get; set; }

    [Required, RegularExpression("^(Pendente|EmAndamento|Concluida)$", ErrorMessage = "Situação inválida.")]
    public string Situacao { get; set; } = "Pendente";
}
