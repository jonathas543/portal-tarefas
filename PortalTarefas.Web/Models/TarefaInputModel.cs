using System.ComponentModel.DataAnnotations;

namespace PortalTarefas.Web.Models;

public class TarefaInputModel : IValidatableObject
{
    [Required(ErrorMessage = "O título é obrigatório.")]
    [StringLength(100, ErrorMessage = "O título deve ter até 100 caracteres.")]
    public string Titulo { get; set; } = string.Empty;

    [StringLength(500, ErrorMessage = "A descrição deve ter até 500 caracteres.")]
    public string? Descricao { get; set; }

    public Prioridade Prioridade { get; set; } = Prioridade.Normal;

    [Required(ErrorMessage = "O prazo é obrigatório."), DataType(DataType.Date)]
    public DateTime? Prazo { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Prazo is null) yield break;
        var hoje = DateTime.Today;

        if (Prazo.Value.Date < hoje)
            yield return new ValidationResult("O prazo não pode estar no passado.", new[] { nameof(Prazo) });

        if (Prioridade == Prioridade.Urgente && Prazo.Value.Date > hoje.AddDays(3))
            yield return new ValidationResult("Tarefas urgentes exigem prazo de, no máximo, 3 dias.",
                new[] { nameof(Prazo), nameof(Prioridade) });
    }
}
