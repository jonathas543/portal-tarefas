namespace PortalTarefas.Web.Models;

public enum Prioridade { Baixa, Normal, Urgente }

public class Tarefa
{
    public Guid Id { get; set; }
    public string Titulo { get; set; } = string.Empty;
    public string? Descricao { get; set; }
    public Prioridade Prioridade { get; set; } = Prioridade.Normal;
    public DateTime Prazo { get; set; }
    public string Situacao { get; set; } = "Pendente";
    public byte[] RowVersion { get; set; } = [];
    public List<AuditoriaTarefa> Auditorias { get; set; } = [];
}

public class AuditoriaTarefa
{
    public int Id { get; set; }
    public Guid TarefaId { get; set; }
    public string Evento { get; set; } = string.Empty;
    public DateTime OcorridoEmUtc { get; set; }
}
