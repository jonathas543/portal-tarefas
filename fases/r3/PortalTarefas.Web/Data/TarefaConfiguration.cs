using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Data;

public class TarefaConfiguration : IEntityTypeConfiguration<Tarefa>
{
    public void Configure(EntityTypeBuilder<Tarefa> b)
    {
        b.ToTable("Tarefas");
        b.HasKey(t => t.Id);
        b.Property(t => t.Titulo).IsRequired().HasMaxLength(100);
        b.Property(t => t.Descricao).HasMaxLength(500);
        b.Property(t => t.Situacao).IsRequired().HasMaxLength(20);
        b.Property(t => t.Prioridade).HasConversion<string>().HasMaxLength(10);
        b.Property(t => t.Prazo).HasColumnType("date");
        b.Property(t => t.RowVersion).IsRowVersion();          // token de concorrência (SQL Server)
        b.HasMany(t => t.Auditorias).WithOne().HasForeignKey(a => a.TarefaId).OnDelete(DeleteBehavior.Cascade);
    }
}
