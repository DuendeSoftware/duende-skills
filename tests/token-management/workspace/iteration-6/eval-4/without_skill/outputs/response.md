# DPoP with client credentials

```csharp
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("invoice.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("webapp");
        client.ClientSecret = ClientSecret.Parse(builder.Configuration["IdentityServer:ClientSecret"]!);
        client.Scope = Scope.Parse("invoice");

        // a persisted key, so DPoP binding survives restarts
        client.DPoPJsonWebKey = DPoPProofKey.Parse(builder.Configuration["DPoP:JsonWebKey"]!);
    });

builder.Services.AddClientCredentialsHttpClient("invoices",
    ClientCredentialsClientName.Parse("invoice.client"),
    c => c.BaseAddress = new Uri("https://api.example.com/invoices/"));
```

```csharp
app.MapGet("/call-api", async (IHttpClientFactory f, CancellationToken ct) =>
{
    var http = f.CreateClient("invoices");
    return Results.Ok(await http.GetStringAsync("", ct));
});
```

Why this keeps the key stable: if no key is configured, a new one is generated per process, so every restart invalidates tokens bound to the old key (`cnf.jkt`). Supplying the JWK from configuration means the same key is used each time. Store the JWK in a secret store (Key Vault, etc.), not in plain appsettings, and use a supported algorithm such as PS256/ES256. The handler adds the `DPoP` proof header and handles `DPoP-Nonce` challenges automatically.
