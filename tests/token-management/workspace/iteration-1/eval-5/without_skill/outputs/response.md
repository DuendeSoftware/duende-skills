# Two HTTP Clients with Different Token Sources

```csharp
// User token client for invoices
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

// Client credentials client for master data
builder.Services.AddClientAccessTokenHttpClient(
    "masterdata",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/masterdata/");
    });

builder.Services.AddOpenIdConnectAccessTokenManagement();
```

The first client attaches the user's access token, while the second uses client credentials for machine-to-machine access.
