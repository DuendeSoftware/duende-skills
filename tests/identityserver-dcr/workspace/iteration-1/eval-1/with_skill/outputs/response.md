# Setting Up Dynamic Client Registration

Here's the full setup for adding DCR to your existing IdentityServer:

## 1. Add the NuGet Package

```bash
dotnet add package Duende.IdentityServer.Configuration
```

## 2. Register Services and Map Endpoint

```csharp
var builder = WebApplication.CreateBuilder(args);

// Existing IdentityServer setup
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Add DCR services
builder.Services.AddIdentityServerConfiguration();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

// Map the DCR endpoint at /connect/dcr
app.MapDynamicClientRegistration()
    .RequireAuthorization(); // ALWAYS secure the endpoint

app.Run();
```

## Important Notes

### License Requirement

Dynamic Client Registration requires a **Business Edition** or higher license. It is not available in the Community Edition.

### Security

The `RequireAuthorization()` call is critical. Without it, anyone can register clients on your IdentityServer. You should configure a proper authorization policy (see the securing DCR endpoint pattern).

### Persistent Storage

For production, you need a persistent client store. The in-memory store won't survive application restarts:

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```
