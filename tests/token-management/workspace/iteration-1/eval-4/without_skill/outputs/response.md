# DPoP with Token Management

```csharp
var builder = WebApplication.CreateBuilder(args);

var dpopKey = builder.Configuration["DPoP:JsonWebKey"];

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("my-client", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "my-client-id";
        client.ClientSecret = "my-client-secret";
        client.Scope = "api1";
        client.DPoPJsonWebKey = dpopKey;
    });
```

Make sure to load the JWK from configuration rather than generating a new key each time. Generating keys on every restart would invalidate previously bound tokens.
