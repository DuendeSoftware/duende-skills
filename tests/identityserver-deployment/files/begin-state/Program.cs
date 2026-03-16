using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

public static class Config
{
    public static IEnumerable<Duende.IdentityServer.Models.IdentityResource> IdentityResources =>
        new[]
        {
            new Duende.IdentityServer.Models.IdentityResources.OpenId(),
            new Duende.IdentityServer.Models.IdentityResources.Profile()
        };

    public static IEnumerable<Duende.IdentityServer.Models.ApiScope> ApiScopes =>
        new[]
        {
            new Duende.IdentityServer.Models.ApiScope("api1", "My API")
        };

    public static IEnumerable<Duende.IdentityServer.Models.Client> Clients =>
        new[]
        {
            new Duende.IdentityServer.Models.Client
            {
                ClientId = "client",
                AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
                ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
                AllowedScopes = { "api1" }
            }
        };
}
