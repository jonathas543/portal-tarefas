using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using PortalTarefas.Web.Models;

namespace PortalTarefas.Web.Data;

public class PortalTarefasDbContext(DbContextOptions<PortalTarefasDbContext> options)
    : IdentityDbContext<IdentityUser>(options)
{
    public DbSet<Tarefa> Tarefas => Set<Tarefa>();
    public DbSet<AuditoriaTarefa> Auditorias => Set<AuditoriaTarefa>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);       // obrigatório: mapeia as tabelas do Identity
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(PortalTarefasDbContext).Assembly);
        modelBuilder.Entity<AuditoriaTarefa>().Property(a => a.Evento).IsRequired().HasMaxLength(200);
    }
}
