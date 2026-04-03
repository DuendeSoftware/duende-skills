# Upgrading Token Management from v3 to v4

Here's your v3 code updated to v4 patterns.

## Updated Registration

```csharp
// v4: No need for AddDistributedMemoryCache() — v4 uses HybridCache automatically
// (two-tier: in-memory L1 + optional distributed L2)

services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });
```

### What changed in registration:
- **Removed `AddDistributedMemoryCache()`** — v4 uses `HybridCache` automatically; no explicit distributed cache registration is required for the default in-memory tier.
- **Strongly-typed property setters** — `ClientId.Parse()`, `ClientSecret.Parse()`, `Scope.Parse()` replace raw string assignments.
- **`TokenEndpoint`** now takes a `Uri` instead of a string.

## Updated Service

```csharp
public class MyService
{
    // v4: IClientCredentialsTokenManager replaces IClientCredentialsTokenManagementService
    private readonly IClientCredentialsTokenManager _tokenManager;

    public MyService(IClientCredentialsTokenManager tokenManager)
    {
        _tokenManager = tokenManager;
    }

    public async Task DoWork(CancellationToken ct)
    {
        // v4: Use ClientCredentialsClientName.Parse() instead of a raw string
        var tokenResult = await _tokenManager.GetAccessTokenAsync(
            ClientCredentialsClientName.Parse("api-client"),
            ct: ct);

        // v4: Check .Succeeded before calling .GetToken()
        // .GetToken() throws InvalidOperationException if Succeeded is false
        if (!tokenResult.Succeeded)
        {
            // Log error and handle failure
            throw new InvalidOperationException("Failed to obtain access token");
        }

        var token = tokenResult.GetToken();
        client.SetBearerToken(token.AccessToken.ToString());
    }
}
```

## Summary of v3 → v4 Changes

| Area | v3 | v4 |
|---|---|---|
| Service interface | `IClientCredentialsTokenManagementService` | `IClientCredentialsTokenManager` |
| Client name type | `string` (`"api-client"`) | `ClientCredentialsClientName.Parse("api-client")` |
| Token result | `token.Value` (direct access) | `tokenResult.Succeeded` check + `tokenResult.GetToken()` |
| Cache | `IDistributedCache` (requires `AddDistributedMemoryCache()`) | `HybridCache` (automatic, two-tier L1+L2) |
| Property types | Raw strings | `ClientId.Parse()`, `ClientSecret.Parse()`, `Scope.Parse()` |
| Token endpoint | `string` | `Uri` |

## Important Notes

1. **`IClientCredentialsTokenManagementService` → `IClientCredentialsTokenManager`**: The interface was renamed. Update all DI registrations and constructor injections.
2. **`ClientCredentialsClientName.Parse()`**: v4 uses strongly-typed client names. Replace all raw string client name arguments.
3. **Always check `.Succeeded`** before calling `.GetToken()`. In v3, you accessed `.Value` directly, but in v4, `.GetToken()` throws `InvalidOperationException` if the token request failed.
4. **`AddDistributedMemoryCache()` is no longer required**: v4's `HybridCache` handles caching automatically with an in-memory L1 tier. You can still add Redis as an L2 tier with `AddStackExchangeRedisCache()`.
5. **Strongly-typed property setters**: Use `ClientId.Parse()`, `ClientSecret.Parse()`, and `Scope.Parse()` instead of assigning raw strings.
