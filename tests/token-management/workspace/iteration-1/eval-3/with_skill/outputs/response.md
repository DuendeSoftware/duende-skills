# Upgrading from v3 to v4

## Updated Registration

```csharp
// v4: No need for AddDistributedMemoryCache() — v4 uses HybridCache automatically
// services.AddDistributedMemoryCache(); // REMOVE THIS — no longer needed in v4

services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });
```

## Updated Manual Token Retrieval

```csharp
// v4: Use IClientCredentialsTokenManager (not IClientCredentialsTokenManagementService)
public class MyService
{
    private readonly IClientCredentialsTokenManager _tokenManager;
    private readonly IHttpClientFactory _factory;

    public MyService(IClientCredentialsTokenManager tokenManager, IHttpClientFactory factory)
    {
        _tokenManager = tokenManager;
        _factory = factory;
    }

    public async Task DoWork(CancellationToken ct)
    {
        // v4: Use ClientCredentialsClientName.Parse() — not a raw string
        var tokenResult = await _tokenManager.GetAccessTokenAsync(
            ClientCredentialsClientName.Parse("api-client"), ct: ct);

        // v4: Check .Succeeded before calling .GetToken()
        if (!tokenResult.Succeeded)
        {
            // Handle failure — do NOT call .GetToken() here, it throws InvalidOperationException
            throw new InvalidOperationException("Failed to obtain access token");
        }

        var token = tokenResult.GetToken();
        var client = _factory.CreateClient();
        client.SetBearerToken(token.AccessToken.ToString());

        var response = await client.GetAsync("https://apis.company.com/api1/data", ct);
    }
}
```

## Summary of Changes

| Area | v3 | v4 |
|------|----|----|
| Service interface | `IClientCredentialsTokenManagementService` | `IClientCredentialsTokenManager` |
| Token result | `.Value` | `.Succeeded` / `.GetToken()` |
| Client name type | `string` ("api-client") | `ClientCredentialsClientName.Parse("api-client")` |
| Property types | Plain strings | `ClientId.Parse()`, `ClientSecret.Parse()`, `Scope.Parse()` |
| Cache | `IDistributedCache` (requires `AddDistributedMemoryCache()`) | `HybridCache` (automatic, no explicit registration needed) |
