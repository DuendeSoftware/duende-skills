# Protecting Local API Endpoints in IdentityServer

If you're hosting an API inside the same application as IdentityServer, you can validate tokens locally without making network calls.

## Setup

You can use the local API authentication feature that comes with Duende IdentityServer:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Enable local API authentication
builder.Services.AddLocalApiAuthentication();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

// Protect endpoints
app.MapGet("/api/data", () => Results.Ok(new { message = "Protected" }))
    .RequireAuthorization("IdentityServerApiPolicy");

app.Run();
```

## How It Works

The `AddLocalApiAuthentication()` method registers an authentication handler that validates tokens locally using IdentityServer's built-in token validation. This avoids the network round-trip that JWT bearer or introspection would require.

You can apply authorization to your endpoints using the policy or scheme that gets registered. The typical approach is to use the policy name that comes built-in.

## Considerations

- This approach is useful for admin endpoints or management APIs that live in the same process as IdentityServer
- Tokens are validated using the internal token validation, so performance is better than making HTTP calls
- Make sure clients requesting tokens for this API have the appropriate scopes configured
