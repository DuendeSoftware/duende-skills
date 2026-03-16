// Program.cs — IdentityServer host with basic configuration, no advanced token security yet
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();

// Minimal configuration classes
public static class Config
{
    public static IEnumerable<Duende.IdentityServer.Models.IdentityResource> IdentityResources =>
    [
        new Duende.IdentityServer.Models.IdentityResources.OpenId(),
        new Duende.IdentityServer.Models.IdentityResources.Profile()
    ];

    public static IEnumerable<Duende.IdentityServer.Models.ApiScope> ApiScopes =>
    [
        new Duende.IdentityServer.Models.ApiScope("api1", "My API")
    ];

    public static IEnumerable<Duende.IdentityServer.Models.Client> Clients =>
    [
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "machine_client",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
            ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "web_app",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Duende.IdentityServer.Models.Secret("web_secret".Sha256()) },
            RedirectUris = { "https://webapp.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true
        }
    ];
}
