using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.ViewModels;

public record TarefaViewModel(Guid Id, string Titulo, string? Descricao,
                              Prioridade Prioridade, DateTime Prazo, string Situacao)
{
    public bool Vencida => Situacao != "Concluida" && Prazo.Date < DateTime.Today;
}
