# Protecting Local APIs in the IdentityServer Host

When your API is in the same application as IdentityServer, you can use local API authentication to avoid network overhead.

## Setup

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Add local API authentication
builder.Services.AddLocalApiAuthentication();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/local-api/data", () => Results.Ok(new { message = "Local data" }))
    .RequireAuthorization("LocalApi");

app.Run();
```

## Configuration

The local API authentication sets up a scheme that validates access tokens internally. You need to make sure clients requesting access to the local API have the appropriate scope configured.

This approach saves the network round-trip of token validation since the API is co-located with the identity provider.
