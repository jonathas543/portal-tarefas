using System.Diagnostics;
using System.Security.Claims;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Http.Resilience;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using PortalTarefas.Web;
using Microsoft.OpenApi;               // OpenApiSpecVersion
using Scalar.AspNetCore;
using PortalTarefas.Web.Data;
using PortalTarefas.Web.Endpoints;
using PortalTarefas.Web.Filters;
using PortalTarefas.Web.Middlewares;
using PortalTarefas.Web.Options;
using PortalTarefas.Web.Services;

var builder = WebApplication.CreateBuilder(args);

// Relatório 7: logs estruturados (JSON) com escopos, incluindo o CorrelationId
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(o => o.IncludeScopes = true);

builder.Services.AddControllersWithViews()                        // MVC + API
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));

// Relatório 4: Problem Details com traceId e documento OpenAPI 3.0 (compatível com NSwag)
builder.Services.AddProblemDetails(o => o.CustomizeProblemDetails = ctx =>
    ctx.ProblemDetails.Extensions["traceId"] = Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier);
builder.Services.AddOpenApi(o => o.OpenApiVersion = OpenApiSpecVersion.OpenApi3_0);
builder.Services.AddScoped<LogActionFilter>();

// Relatório 8: a connection string vem do ambiente (User Secrets em Desenvolvimento, variáveis no contêiner)
// e é validada na inicialização; a mensagem cita o campo, nunca o valor.
builder.Services.AddOptions<BancoOptions>()
    .BindConfiguration("ConnectionStrings")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddDbContextPool<PortalTarefasDbContext>((sp, o) =>
    o.UseSqlServer(sp.GetRequiredService<IOptions<BancoOptions>>().Value.DefaultConnection));
builder.Services.AddScoped<ITarefaService, TarefaDbService>();   // substitui TarefaMemoriaService
builder.Services.AddScoped<TarefaTransacaoService>();
builder.Services.AddScoped<PainelQueries>();
builder.Services.AddScoped<TarefasApiService>();

// Relatório 6: ASP.NET Core Identity com cookie HttpOnly, roles, claims e políticas
builder.Services.AddIdentity<IdentityUser, IdentityRole>(o =>
{
    o.Password.RequiredLength = 10;
    o.Lockout.AllowedForNewUsers = true;
    o.Lockout.MaxFailedAccessAttempts = 5;
    o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    o.User.RequireUniqueEmail = true;
}).AddEntityFrameworkStores<PortalTarefasDbContext>();

// Revalida o security stamp a cada requisição: o logout invalida cookies já emitidos
builder.Services.Configure<SecurityStampValidatorOptions>(o => o.ValidationInterval = TimeSpan.Zero);

builder.Services.ConfigureApplicationCookie(o =>
{
    o.Cookie.Name = "portaltarefas.auth";
    o.Cookie.HttpOnly = true;
    o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    o.Cookie.SameSite = SameSiteMode.Strict;
    o.ExpireTimeSpan = TimeSpan.FromHours(1);
    o.SlidingExpiration = true;
    o.Events.OnRedirectToLogin = ctx =>               // 401 em vez de redirecionamento
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        return Task.CompletedTask;
    };
    o.Events.OnRedirectToAccessDenied = ctx =>        // 403 + auditoria (sem dados sensíveis)
    {
        var log = ctx.HttpContext.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("Auditoria");
        log.LogWarning("Acesso negado: {Metodo} {Caminho} usuário {UsuarioId}",
            ctx.Request.Method, ctx.Request.Path, ctx.HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier));
        ctx.Response.StatusCode = StatusCodes.Status403Forbidden;
        return Task.CompletedTask;
    };
});

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("SomenteAdmin", p => p.RequireRole("Administrador"))
    .AddPolicy("EditarOutraEquipe", p => p.RequireClaim("permissao", "editar-outra-equipe"));

// Relatório 7: OpenTelemetry (traces e métricas exportados para o console)
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService(Telemetria.Nome))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddSqlClientInstrumentation()
        .AddSource(Telemetria.Nome).AddConsoleExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation().AddHttpClientInstrumentation()
        .AddMeter(Telemetria.Nome)
        .AddConsoleExporter((_, leitor) =>
            leitor.PeriodicExportingMetricReaderOptions.ExportIntervalMilliseconds = 10_000));   // a cada 10 s

// Health Checks: liveness sem dependências; readiness com banco e dependência HTTP
var urlDependencia = new Uri(builder.Configuration["Dependencias:Url"] ?? "https://localhost:7000");
builder.Services.AddHttpClient("dependencia-saude", c => c.BaseAddress = urlDependencia);
builder.Services.AddHealthChecks()
    .AddDbContextCheck<PortalTarefasDbContext>("banco", tags: ["ready"])
    .AddCheck<DependenciaHttpHealthCheck>("dependencia", tags: ["ready"]);

// Cliente HTTP resiliente (retry só em métodos seguros, timeout e circuit breaker)
builder.Services.AddHttpClient<ServicoExterno>(c => c.BaseAddress = urlDependencia)
    .AddStandardResilienceHandler(o =>
    {
        o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(2);
        o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);
        o.Retry.MaxRetryAttempts = 2;
        o.Retry.Delay = TimeSpan.FromMilliseconds(200);
        o.Retry.DisableForUnsafeHttpMethods();                 // nunca repetir POST/PUT/DELETE
        o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
        o.CircuitBreaker.MinimumThroughput = 5;                // valor baixo, apenas para demonstração
        o.CircuitBreaker.FailureRatio = 0.5;
        o.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(15);
    });

// Rate limiting (janela fixa) e output caching
var limite = builder.Configuration.GetValue("RateLimit:Requisicoes", 100);
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddFixedWindowLimiter("api", l => { l.PermitLimit = limite; l.Window = TimeSpan.FromMinutes(1); l.QueueLimit = 0; });
    o.OnRejected = (ctx, _) =>
    {
        ctx.HttpContext.Response.Headers.RetryAfter = "60";
        ctx.HttpContext.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("RateLimit")
            .LogWarning("Limite excedido em {Caminho}", ctx.HttpContext.Request.Path);
        return ValueTask.CompletedTask;
    };
});
builder.Services.AddOutputCache(o => o.AddPolicy("Publico30s", b => b.Expire(TimeSpan.FromSeconds(30)).Tag("publico")));

// CORS só é configurado se houver origens (em produção a SPA é servida pela própria API)
var origens = builder.Configuration.GetSection("Cors:Origens").Get<string[]>() ?? [];
if (origens.Length > 0)
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
    await IdentitySeeder.SeedAsync(escopo.ServiceProvider, builder.Configuration);   // senhas em User Secrets
}

app.UseExceptionHandler();      // 1. captura falhas de todos os componentes seguintes
app.UseStatusCodePages();       // 2. 404/4xx sem corpo -> Problem Details
app.UseRequestLogging();        // 3. correlação, entrada e saída
app.UseHttpsRedirection();      // 4. HTTP -> HTTPS
app.UseDefaultFiles();          // 5a. "/" -> index.html da SPA (quando existir em wwwroot)
app.UseStaticFiles();           // 5b. arquivos estáticos (curto-circuito)
app.UseRouting();               // 6. escolhe o endpoint
if (origens.Length > 0)
    app.UseCors("FrontLocal");  // 7. CORS depois do roteamento
app.UseAuthentication();        // 8. identifica o usuário (cookie)
app.UseAuthorization();         // 9. aplica [Authorize] e políticas
app.UseRateLimiter();           // 10. limita requisições por janela
app.UseOutputCache();           // 11. cache de saída (endpoint público)

app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = r => r.Tags.Contains("ready") });

var publico = app.MapGroup("/api/publico").RequireRateLimiting("api").AllowAnonymous();
publico.MapGet("/estatisticas", async (PortalTarefasDbContext db, CancellationToken ct) =>
{
    var porSituacao = await db.Tarefas.AsNoTracking().GroupBy(t => t.Situacao)
        .Select(g => new { situacao = g.Key, total = g.Count() }).ToListAsync(ct);
    return Results.Ok(new { geradoEm = DateTime.UtcNow, porSituacao });
}).CacheOutput("Publico30s");

app.MapConta();                 // /api/conta/login, /logout, /me

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

    // Simulações didáticas de dependência externa (Relatório 7)
    var chamadas = 0;
    app.MapGet("/simulacao/instavel", () => Interlocked.Increment(ref chamadas) % 3 == 0
        ? Results.Ok(new { ok = true }) : Results.StatusCode(503)).AllowAnonymous();   // 2 falhas, 1 sucesso
    app.MapGet("/simulacao/fora", () => Results.StatusCode(503)).AllowAnonymous();
    app.MapGet("/api/externo/instavel", (ServicoExterno s, CancellationToken ct) => s.ChamarAsync("/simulacao/instavel", ct));
    app.MapGet("/api/externo/fora", (ServicoExterno s, CancellationToken ct) => s.ChamarAsync("/simulacao/fora", ct));

    // Painel: mesma consulta via EF Core (SQL gerado aparece no log) e via Dapper (SQL explícito)
    dev.MapGet("/painel/ef", async (DateTime? ate, PainelQueries q, CancellationToken ct)
        => Results.Ok(await q.ResumoEfAsync(ate ?? new DateTime(2026, 12, 31), ct)));
    dev.MapGet("/painel/dapper", async (DateTime? ate, PainelQueries q, CancellationToken ct)
        => Results.Ok(await q.ResumoDapperAsync(ate ?? new DateTime(2026, 12, 31), ct)));
}

app.MapControllers().RequireRateLimiting("api");   // API (rotas por atributo), com limite
app.MapControllerRoute(name: "default",
    pattern: "{controller=TarefasMvc}/{action=Index}/{id?}");   // interface MVC

// SPA servida pela API: rotas do React que não são /api nem /health caem no index.html
app.MapFallbackToFile("/{*path:regex(^(?!api/|health/).*)}", "index.html");

app.Run();
