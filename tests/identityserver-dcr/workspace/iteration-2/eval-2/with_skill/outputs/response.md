To secure the `/connect/dcr` endpoint with JWT bearer authentication and a scope check, configure authentication, an authorization policy, and apply it to `MapDynamicClientRegistration()`.

### Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

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

builder.Services.AddIdentityServerConfiguration();

// Configure JWT bearer authentication for the DCR endpoint
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Configure authorization policy requiring the IdentityServer.Configuration scope
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

// Map DCR endpoint with the authorization policy
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.MapRazorPages();

app.Run();
```

### How it works

1. **`AddJwtBearer("dcr", ...)`** configures a named JWT bearer authentication scheme with:
   - `Authority` set to your IdentityServer URL for discovery document and key validation
   - `Audience` set to `"IdentityServer.Configuration"` to validate the `aud` claim
   - `ValidTypes` set to `["at+jwt"]` to only accept access tokens

2. **`AddAuthorization()`** creates a named policy `"dcr"` that:
   - Uses the `"dcr"` authentication scheme
   - Requires an authenticated user
   - Requires the `scope` claim to contain `"IdentityServer.Configuration"`

3. **`MapDynamicClientRegistration().RequireAuthorization("dcr")`** applies the policy to the DCR endpoint, ensuring only callers with a valid access token containing the correct scope can register clients.

The `dcr.manager` client in your configuration is already set up with `IdentityServer.Configuration` scope, so it can obtain a token and call the DCR endpoint.
