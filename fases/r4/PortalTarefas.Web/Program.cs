using System.Diagnostics;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;               // OpenApiSpecVersion
using Scalar.AspNetCore;
using PortalTarefas.Web.Data;
using PortalTarefas.Web.Filters;
using PortalTarefas.Web.Middlewares;
using PortalTarefas.Web.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews()                        // MVC + API
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));

// Relatório 4: Problem Details com traceId e documento OpenAPI 3.0 (compatível com NSwag)
builder.Services.AddProblemDetails(o => o.CustomizeProblemDetails = ctx =>
    ctx.ProblemDetails.Extensions["traceId"] = Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier);
builder.Services.AddOpenApi(o => o.OpenApiVersion = OpenApiSpecVersion.OpenApi3_0);
builder.Services.AddScoped<LogActionFilter>();

// Relatório 3: persistência com EF Core (connection string em User Secrets)
var cs = builder.Configuration.GetConnectionString("DefaultConnection")
         ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection não configurada.");

builder.Services.AddDbContextPool<PortalTarefasDbContext>(o => o.UseSqlServer(cs));
builder.Services.AddScoped<ITarefaService, TarefaDbService>();   // substitui TarefaMemoriaService
builder.Services.AddScoped<TarefaTransacaoService>();
builder.Services.AddScoped<PainelQueries>();
builder.Services.AddScoped<TarefasApiService>();

var origens = builder.Configuration.GetSection("Cors:Origens").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddPolicy("FrontLocal", p => p
    .WithOrigins(origens)
    .WithMethods("GET", "POST", "PUT", "DELETE")
    .WithHeaders("Content-Type", "X-Client-Id")));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    using var escopo = app.Services.CreateScope();
    var db = escopo.ServiceProvider.GetRequiredService<PortalTarefasDbContext>();
    await db.Database.MigrateAsync();
    await DbSeeder.SeedAsync(db);
}

app.UseExceptionHandler();      // 1. captura falhas de todos os componentes seguintes
app.UseStatusCodePages();       // 2. 404/4xx sem corpo -> Problem Details
app.UseRequestLogging();        // 3. correlação, entrada e saída
app.UseHttpsRedirection();      // 4. HTTP -> HTTPS
app.UseStaticFiles();           // 5. arquivos estáticos (curto-circuito)
app.UseRouting();               // 6. escolhe o endpoint
app.UseCors("FrontLocal");      // 7. CORS depois do roteamento

var diagnostico = app.MapGroup("/api/diagnostico");   // Minimal API em grupo próprio
diagnostico.MapGet("/ping", () => Results.Ok(new
{
    status = "ok", origem = "minimal-api", horaUtc = DateTime.UtcNow
}));

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();                  // /openapi/v1.json
    app.MapScalarApiReference();       // /scalar/v1 (somente em Desenvolvimento)

    diagnostico.MapGet("/erro", IResult () => throw new InvalidOperationException("Falha simulada"));

    // Endpoints didáticos do Relatório 3 (somente Desenvolvimento)
    var dev = app.MapGroup("/api/dev");

    // Transação: altera a situação com o rowVersion atual; falhar=true provoca falha entre as duas gravações
    dev.MapPost("/tarefas/{id:guid}/situacao", async (Guid id, string nova, bool? falhar,
        PortalTarefasDbContext db, TarefaTransacaoService servico, CancellationToken ct) =>
    {
        var atual = await db.Tarefas.AsNoTracking().FirstOrDefaultAsync(t => t.Id == id, ct);
        if (atual is null) return Results.NotFound();
        try
        {
            await servico.AlterarSituacaoAsync(id, nova, atual.RowVersion, falhar ?? false, ct);
            return Results.Ok(new { id, situacao = nova, transacao = "commit" });
        }
        catch (InvalidOperationException ex)
        {
            return Results.Problem(statusCode: 500, title: "Transação desfeita (rollback).", detail: ex.Message);
        }
    });

    // Painel: mesma consulta via EF Core (SQL gerado aparece no log) e via Dapper (SQL explícito)
    dev.MapGet("/painel/ef", async (DateTime? ate, PainelQueries q, CancellationToken ct)
        => Results.Ok(await q.ResumoEfAsync(ate ?? new DateTime(2026, 12, 31), ct)));
    dev.MapGet("/painel/dapper", async (DateTime? ate, PainelQueries q, CancellationToken ct)
        => Results.Ok(await q.ResumoDapperAsync(ate ?? new DateTime(2026, 12, 31), ct)));
}

app.MapControllers();           // API (rotas por atributo)
app.MapControllerRoute(name: "default",
    pattern: "{controller=TarefasMvc}/{action=Index}/{id?}");   // interface MVC

app.Run();
