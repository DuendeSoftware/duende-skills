# Separate DCR Host

Here's how to set up a separate application that hosts the DCR endpoint, pointing to your main IdentityServer:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Point to the main IdentityServer instance
builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
});

// Add the client configuration store (must share the same database as IdentityServer)
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();

// JWT Bearer authentication for the DCR endpoint
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

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

app.UseAuthentication();
app.UseAuthorization();

app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## Key Points

1. **`IdentityServerBaseUrl`**: Points to the main IdentityServer at `https://identity.example.com`. This tells the DCR host where to find IdentityServer's discovery document and signing keys.

2. **No `AddIdentityServer()`**: This is a separate host, not an IdentityServer instance. Do NOT call `AddIdentityServer()` — only `AddIdentityServerConfiguration()`.

3. **Shared Data Store**: The `IClientConfigurationStore` must be backed by the **same database** that IdentityServer reads from. When the DCR host registers a new client, IdentityServer must be able to find it when the client tries to authenticate.

4. **JWT Bearer Authentication**: The DCR endpoint is secured with JWT bearer tokens issued by the main IdentityServer. This means callers must first get an access token from IdentityServer, then use it to register clients.
