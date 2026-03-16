using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// TODO: Configure IdentityServer with stores here

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

// Static configuration for seeding
public static class Config
{
    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "api-client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];
}
