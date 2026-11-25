using System.ComponentModel.DataAnnotations;

namespace PortalTarefas.Web.Options;

public sealed class BancoOptions
{
    [Required(ErrorMessage = "ConnectionStrings:DefaultConnection é obrigatória.")]
    public string DefaultConnection { get; set; } = string.Empty;
}
