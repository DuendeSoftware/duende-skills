# Upgrading from v3 to v4 of Duende.AccessTokenManagement

## Updated Registration

```csharp
// v4: No AddDistributedMemoryCache() needed — v4 uses HybridCache automatically
services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("api-client"), client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });
```

## Updated Manual Token Retrieval

```csharp
public class MyService
{
    private readonly IClientCredentialsTokenManager _tokenManager; // v4 interface name

    public MyService(IClientCredentialsTokenManager tokenManager)
    {
        _tokenManager = tokenManager;
    }

    public async Task DoWork()
    {
        var tokenResult = await _tokenManager.GetAccessTokenAsync(
            ClientCredentialsClientName.Parse("api-client"));

        // v4: Check Succeeded before calling GetToken()
        if (!tokenResult.Succeeded)
        {
            // Handle failure — log, retry, throw
            throw new InvalidOperationException("Failed to obtain token");
        }

        var token = tokenResult.GetToken();
        client.SetBearerToken(token.AccessToken.ToString());
    }
}
```

## Key Changes from v3 to v4

| Area | v3 | v4 |
|---|---|---|
| **Service interface** | `IClientCredentialsTokenManagementService` | `IClientCredentialsTokenManager` |
| **Client name type** | Raw `string` (`"api-client"`) | `ClientCredentialsClientName.Parse("api-client")` |
| **Token result** | `token.Value` (direct access) | `tokenResult.Succeeded` + `tokenResult.GetToken()` |
| **Property setters** | Plain strings | Strongly-typed: `ClientId.Parse()`, `ClientSecret.Parse()`, `Scope.Parse()` |
| **TokenEndpoint** | `string` | `Uri` |
| **Caching** | `IDistributedCache` (must register `AddDistributedMemoryCache()`) | `HybridCache` (automatic, two-tier L1+L2) |

## Why These Changes Matter

- **`AddDistributedMemoryCache()` is no longer required**: v4 uses `HybridCache` which provides a two-tier cache (in-memory L1 + optional distributed L2) automatically. Remove the explicit `AddDistributedMemoryCache()` call.

- **Strongly-typed names prevent typos**: `ClientCredentialsClientName.Parse()` ensures the client name is validated at parse time, not at runtime when a token request fails.

- **`Succeeded` check prevents exceptions**: In v3, accessing `.Value` on a failed response could return null silently. In v4, calling `.GetToken()` without checking `.Succeeded` throws `InvalidOperationException`, making failures explicit.
