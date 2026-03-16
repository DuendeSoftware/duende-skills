// Program.cs — Minimal IdentityServer with basic resources (no custom profile service)
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users);

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();

// Configuration classes
public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        // Machine-to-machine client
        new Client
        {
            ClientId = "m2m.client",
            ClientName = "M2M Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        // Interactive client (OIDC)
        new Client
        {
            ClientId = "interactive",
            ClientName = "Interactive Client",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "email", "api1" }
        }
    ];
}

// Placeholder for TestUsers — normally from Duende.IdentityServer.Test
public static class TestUsers
{
    public static List<Duende.IdentityServer.Test.TestUser> Users =>
    [
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "password",
            Claims =
            {
                new System.Security.Claims.Claim("name", "Alice Smith"),
                new System.Security.Claims.Claim("email", "alice@example.com"),
            }
        },
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "2",
            Username = "bob",
            Password = "password",
            Claims =
            {
                new System.Security.Claims.Claim("name", "Bob Jones"),
                new System.Security.Claims.Claim("email", "bob@example.com"),
            }
        }
    ];
}
