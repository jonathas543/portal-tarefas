using System.Security.Claims;
using Microsoft.AspNetCore.Identity;

namespace PortalTarefas.Web.Data;

public static class IdentitySeeder
{
    // Senhas vêm de User Secrets (Seed:AdminSenha, Seed:UsuarioSenha); nada fixo no repositório.
    public static async Task SeedAsync(IServiceProvider sp, IConfiguration cfg)
    {
        var roles = sp.GetRequiredService<RoleManager<IdentityRole>>();
        var users = sp.GetRequiredService<UserManager<IdentityUser>>();
        var log = sp.GetRequiredService<ILoggerFactory>().CreateLogger("IdentitySeeder");

        foreach (var r in new[] { "Usuario", "Administrador" })
            if (!await roles.RoleExistsAsync(r)) await roles.CreateAsync(new IdentityRole(r));

        await CriarAsync("admin@portal.local", cfg["Seed:AdminSenha"], "Administrador", comPermissao: true);
        await CriarAsync("usuario@portal.local", cfg["Seed:UsuarioSenha"], "Usuario", comPermissao: false);

        async Task CriarAsync(string email, string? senha, string role, bool comPermissao)
        {
            if (string.IsNullOrWhiteSpace(senha)) { log.LogWarning("Senha de seed ausente para {Role}; usuário não criado.", role); return; }
            if (await users.FindByNameAsync(email) is not null) return;                 // idempotente

            var usuario = new IdentityUser { UserName = email, Email = email, EmailConfirmed = true };
            var resultado = await users.CreateAsync(usuario, senha);
            if (!resultado.Succeeded) { log.LogWarning("Falha ao criar usuário {Role}.", role); return; }

            await users.AddToRoleAsync(usuario, role);
            if (comPermissao) await users.AddClaimAsync(usuario, new Claim("permissao", "editar-outra-equipe"));
        }
    }
}
