using PortalTarefas.Web.Models;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace PortalTarefas.Web.Dtos;

public class TarefaCriarDto
{
    [Required(ErrorMessage = "O título é obrigatório."), StringLength(100)]
    public string Titulo { get; set; } = string.Empty;
    [StringLength(500)] public string? Descricao { get; set; }
    public Prioridade Prioridade { get; set; } = Prioridade.Normal;
    [Required(ErrorMessage = "O prazo é obrigatório.")] public DateTime? Prazo { get; set; }
}

public class TarefaAtualizarDto : TarefaCriarDto
{
    [Required, RegularExpression("^(Pendente|EmAndamento|Concluida)$")]
    public string Situacao { get; set; } = "Pendente";
    [Required] public byte[] RowVersion { get; set; } = [];     // base64 no JSON
}

public record TarefaResumoDto(Guid Id, string Titulo, Prioridade Prioridade, DateTime Prazo, string Situacao);
public record TarefaDetalhesDto(Guid Id, string Titulo, string? Descricao, Prioridade Prioridade,
                                DateTime Prazo, string Situacao, byte[] RowVersion);
public record PaginaDto<T>(IReadOnlyList<T> Itens, int Pagina, int Tamanho, int Total, int TotalPaginas);

public class TarefaConsulta
{
    [Range(1, int.MaxValue)] public int Pagina { get; set; } = 1;
    [Range(1, 50)] public int Tamanho { get; set; } = 10;
    [AllowedValues("titulo", "prazo", "situacao")] public string OrdenarPor { get; set; } = "titulo";
    [AllowedValues("asc", "desc")] public string Direcao { get; set; } = "asc";
    [RegularExpression("^(Pendente|EmAndamento|Concluida)$")] public string? Situacao { get; set; }
    public Prioridade? Prioridade { get; set; }
    [StringLength(50)] public string? Busca { get; set; }
    /// <summary>Filtro opcional (evolução compatível do contrato): tarefas com prazo até esta data.</summary>
    public DateTime? PrazoAte { get; set; }
}
