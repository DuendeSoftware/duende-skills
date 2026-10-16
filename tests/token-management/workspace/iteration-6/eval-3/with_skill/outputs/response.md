# v3 → v4 migration

Changes that affect your code:

| Area | v3 | v4 |
|---|---|---|
| Service | `IClientCredentialsTokenManagementService` | `IClientCredentialsTokenManager` |
| Result | token response, `.Value` | `TokenResult<T>`: `.Succeeded` / `.GetToken()` |
| Names / values | plain strings | `ClientCredentialsClientName`, `ClientId`, `ClientSecret`, `Scope`, `Uri` |
| Cache | `IDistributedCache` (`AddDistributedMemoryCache()` required) | `HybridCache` (automatic; `IDistributedCache` becomes L2) |
| Resiliency | manual | built into `AddClientCredentialsHttpClient` |

## Registration (v4)

```csharp
// ❌ remove: services.AddDistributedMemoryCache();  — HybridCache is used by default
services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });
```
For production, add a Redis `AddStackExchangeRedisCache(...)` and HybridCache picks it up as the L2 tier.

## Preferred: let the library attach tokens

```csharp
services.AddClientCredentialsHttpClient("api",
    ClientCredentialsClientName.Parse("api-client"),
    client => client.BaseAddress = new Uri("https://api.example.com/"));
// consumers just use IHttpClientFactory.CreateClient("api")
```

## Manual retrieval (if you really need it)

```csharp
public sealed class MyService(IClientCredentialsTokenManager tokenManager, IHttpClientFactory factory, ILogger<MyService> logger)
{
    public async Task DoWork(CancellationToken ct)
    {
        var result = await tokenManager.GetAccessTokenAsync(
            ClientCredentialsClientName.Parse("api-client"), ct: ct);

        // ✅ check before calling GetToken(); it throws if retrieval failed
        if (!result.Succeeded)
        {
            logger.LogError("Could not obtain access token");
            return;
        }

        var token = result.GetToken();
        var client = factory.CreateClient();
        client.SetBearerToken(token.AccessToken.ToString());
        // ...
    }
}
```

Note: don't store the token in a field; call the manager each time and it serves from cache. If you register a handler directly (`AddClientCredentialsTokenHandler`), also add `.AddDefaultAccessTokenResiliency()`.
