```csharp
// dotnet add package Duende.AccessTokenManagement
services.AddClientCredentialsTokenManagement()
    .AddClient("my.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-worker");
        client.ClientSecret = ClientSecret.Parse("secret");
        client.Scope = Scope.Parse("api1");
    });

services.AddClientCredentialsHttpClient("api",
    ClientCredentialsClientName.Parse("my.client"),
    client => client.BaseAddress = new Uri("https://api.example.com/"));
```

Then `factory.CreateClient("api")` in your `BackgroundService`. Tokens are acquired, cached (HybridCache, in-memory by default, no extra cache registration) and attached; `AddClientCredentialsHttpClient` also retries once on 401.
