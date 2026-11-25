using System.Security.Claims;
using Microsoft.AspNetCore.Identity;

namespace PortalTarefas.Web.Endpoints;

public record LoginDto(string? Email, string? Senha);

public static class ContaEndpoints
{
    public static IEndpointRouteBuilder MapConta(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/conta");

        g.MapPost("/login", async (LoginDto dto, SignInManager<IdentityUser> sm, ILogger<LoginDto> log) =>
        {
            if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Senha))
                return Results.Problem(statusCode: 401, title: "Credenciais inválidas.");

            var r = await sm.PasswordSignInAsync(dto.Email, dto.Senha, isPersistent: false, lockoutOnFailure: true);
            if (r.Succeeded) return Results.NoContent();

            log.LogWarning("Falha de login (conta bloqueada: {Bloqueada})", r.IsLockedOut);   // sem e-mail/senha
            return Results.Problem(statusCode: 401, title: "Credenciais inválidas.");          // resposta única
        }).AllowAnonymous();

        g.MapPost("/logout", async (ClaimsPrincipal principal, SignInManager<IdentityUser> sm,
                                    UserManager<IdentityUser> um) =>
        {
            var usuario = await um.GetUserAsync(principal);
            await sm.SignOutAsync();
            if (usuario is not null) await um.UpdateSecurityStampAsync(usuario);   // invalida cookies já emitidos
            return Results.NoContent();
        }).RequireAuthorization();

        g.MapGet("/me", (ClaimsPrincipal u) => Results.Ok(new
        {
            email = u.Identity!.Name,
            roles = u.FindAll(ClaimTypes.Role).Select(c => c.Value),
            permissoes = u.FindAll("permissao").Select(c => c.Value)
        })).RequireAuthorization();

        return app;
    }
}
