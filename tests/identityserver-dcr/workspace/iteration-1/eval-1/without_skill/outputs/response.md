# Dynamic Client Registration Setup

To add Dynamic Client Registration:

```csharp
// Add the DCR package
// dotnet add package Duende.IdentityServer.Configuration

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

builder.Services.AddIdentityServerConfiguration();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapDynamicClientRegistration();

app.Run();
```

This sets up the `/connect/dcr` endpoint where clients can register themselves. The endpoint accepts POST requests with client metadata and returns the registered client details including a generated client_id and client_secret.
