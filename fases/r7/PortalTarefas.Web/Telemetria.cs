using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace PortalTarefas.Web;

public static class Telemetria
{
    public const string Nome = "PortalTarefas.Web";
    public static readonly ActivitySource Fonte = new(Nome);
    private static readonly Meter Medidor = new(Nome);

    public static readonly Counter<long> TarefasCriadas =
        Medidor.CreateCounter<long>("tarefas.criadas", description: "Tarefas criadas, por prioridade");
    public static readonly Histogram<double> DuracaoConsulta =
        Medidor.CreateHistogram<double>("tarefas.consulta.duracao", unit: "ms", description: "Duração da listagem");
}
