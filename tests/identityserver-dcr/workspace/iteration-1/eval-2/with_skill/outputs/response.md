# Securing the DCR Endpoint with JWT Bearer

```csharp
var builder = WebApplication.CreateBuilder(args);

// IdentityServer setup (existing)
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

builder.Services.AddIdentityServerConfiguration();

// JWT Bearer for DCR endpoint
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Authorization policy for DCR
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

// Secure the DCR endpoint with the authorization policy
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## How It Works

1. **JWT Bearer scheme** (`dcr`): Validates access tokens issued by the authority at `https://identity.example.com`. The `Audience` ensures only tokens intended for the DCR endpoint are accepted.

2. **Authorization policy** (`dcr`): Requires an authenticated user with the `IdentityServer.Configuration` scope claim. This means only callers who have been granted this specific scope can register clients.

3. **RequireAuthorization("dcr")**: Applies the policy to the `/connect/dcr` endpoint.

## Getting a Token for DCR

The caller must first obtain an access token with the `IdentityServer.Configuration` scope:

```http
POST /connect/token
grant_type=client_credentials&
client_id=dcr-admin&
client_secret=...&
scope=IdentityServer.Configuration
```

Then use it to call the DCR endpoint:

```http
POST /connect/dcr
Authorization: Bearer <access_token>
Content-Type: application/json

{"client_name": "New App", ...}
```
