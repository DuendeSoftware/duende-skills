# Securing the DCR Endpoint with JWT Bearer Authentication

You'll need to set up JWT bearer authentication and an authorization policy, then apply it to the DCR endpoint.

## Updated Program.cs

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

// Add JWT Bearer authentication
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "IdentityServer.Configuration"
        };
    });

// Add authorization with a policy for DCR
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DcrPolicy", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

// Map DCR with authorization
app.MapDynamicClientRegistration()
    .RequireAuthorization("DcrPolicy");

app.MapRazorPages();

app.Run();
```

## Explanation

1. **JWT Bearer Authentication**: We configure a JWT bearer scheme that validates tokens against your IdentityServer instance. The `Authority` tells the middleware where to fetch the discovery document and signing keys.

2. **Authorization Policy**: The `DcrPolicy` requires:
   - An authenticated user (valid bearer token)
   - A `scope` claim matching `IdentityServer.Configuration`

3. **Endpoint Protection**: `RequireAuthorization("DcrPolicy")` ensures that only callers with a valid token containing the correct scope can access the DCR endpoint.

This way, only the `dcr.manager` client (or any other client granted the `IdentityServer.Configuration` scope) can register new clients dynamically.
