# Upgrading Client Credentials Token Management: v3 → v4

Here are the v4 equivalents of your v3 code. The main changes: the service interface, the strongly-typed client name and property setters, the `TokenResult<T>` return type, and the removal of the explicit distributed cache registration (v4 uses `HybridCache`).

## Registration

```csharp
// v4 — no AddDistributedMemoryCache() needed; v4 caches with HybridCache automatically
services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId     = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope        = Scope.Parse("api1");
    });
```

What changed:
- **Removed `services.AddDistributedMemoryCache();`** — v4 caches tokens with `HybridCache` (two-tier L1 in-memory + optional L2 distributed). No explicit cache registration is required. If you later want a shared L2 tier, add `AddStackExchangeRedisCache(...)` and `HybridCache` picks it up automatically.
- **Strongly-typed setters** — `ClientId.Parse(...)`, `ClientSecret.Parse(...)`, `Scope.Parse(...)`, and `TokenEndpoint` as a `Uri`.

## Manual token retrieval

```csharp
public class MyService
{
    // ✅ v4 interface (was IClientCredentialsTokenManagementService)
    private readonly IClientCredentialsTokenManager _tokenManager;

    public MyService(IClientCredentialsTokenManager tokenManager)
    {
        _tokenManager = tokenManager;
    }

    public async Task DoWork(HttpClient client, CancellationToken ct)
    {
        // ✅ Strongly-typed client name; returns TokenResult<ClientCredentialsToken>
        var tokenResult = await _tokenManager.GetAccessTokenAsync(
            ClientCredentialsClientName.Parse("api-client"),
            ct: ct);

        // ✅ Check Succeeded before calling GetToken() — GetToken() throws otherwise
        if (!tokenResult.Succeeded)
        {
            // log / handle failure
            return;
        }

        var token = tokenResult.GetToken();
        client.SetBearerToken(token.AccessToken.ToString());
    }
}
```

## Summary of v3 → v4 changes

| v3 | v4 |
|---|---|
| `IClientCredentialsTokenManagementService` | `IClientCredentialsTokenManager` |
| `GetAccessTokenAsync("api-client")` (raw string) | `GetAccessTokenAsync(ClientCredentialsClientName.Parse("api-client"))` |
| `token.Value` | `tokenResult.Succeeded` + `tokenResult.GetToken()` |
| `client.ClientId = "my-service"` (string) | `ClientId.Parse("my-service")` (also `ClientSecret.Parse`, `Scope.Parse`) |
| `AddDistributedMemoryCache()` required | Not required — `HybridCache` is automatic |

> **Tip:** prefer the `IHttpClientFactory` integration (`AddClientCredentialsHttpClient` / `AddClientCredentialsTokenHandler`) over manual retrieval — it acquires, caches, refreshes, and attaches the token for you, and adds a resiliency handler that retries once on 401.
