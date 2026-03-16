# Securing the DCR Endpoint with JWT Bearer Authentication

To secure the `/connect/dcr` endpoint, you need to configure JWT bearer authentication with a scope-based authorization policy, then apply it to the DCR endpoint mapping.

## Full Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// IdentityServer registration
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1"),
        new ApiScope("api2", "API 2"),
        new ApiScope("IdentityServer.Configuration", "IdentityServer Configuration API")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "email", "api1" },
            AllowOfflineAccess = true
        },
        new Client
        {
            ClientId = "dcr.manager",
            ClientName = "DCR Management Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("dcr-secret".Sha256()) },
            AllowedScopes = { "IdentityServer.Configuration" }
        }
    });

// Add DCR configuration services
builder.Services.AddIdentityServerConfiguration();

// Configure JWT Bearer authentication for the DCR endpoint
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Configure authorization policy requiring the DCR scope
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

// Map the DCR endpoint with the authorization policy
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.MapRazorPages();

app.Run();
```

## How It Works

1. **`AddAuthentication().AddJwtBearer("dcr", ...)`** — Registers a JWT bearer authentication scheme named `"dcr"`. The `Authority` is set to your IdentityServer's URL so it can validate tokens. The `Audience` is set to `"IdentityServer.Configuration"` to match the expected audience of access tokens for this API.

2. **`AddAuthorization(options => ...)`** — Creates a named policy `"dcr"` that:
   - Uses the `"dcr"` authentication scheme
   - Requires the caller to be authenticated
   - Requires the `scope` claim to contain `"IdentityServer.Configuration"`

3. **`MapDynamicClientRegistration().RequireAuthorization("dcr")`** — Maps the `/connect/dcr` endpoint and applies the `"dcr"` authorization policy. Only callers with a valid access token containing the `IdentityServer.Configuration` scope can register new clients.

## Usage Flow

1. The `dcr.manager` client (or any authorized client) obtains an access token from IdentityServer using client credentials with the `IdentityServer.Configuration` scope.
2. The client POSTs to `/connect/dcr` with the access token in the `Authorization: Bearer` header.
3. The DCR endpoint validates the token and checks the scope before processing the registration.

> **Important**: Never expose `MapDynamicClientRegistration()` without `RequireAuthorization()`. An unauthenticated DCR endpoint allows anyone to register clients, which is a serious security risk.
