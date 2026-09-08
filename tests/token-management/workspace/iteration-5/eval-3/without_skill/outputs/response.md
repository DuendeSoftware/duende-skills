# Upgrading Duende.AccessTokenManagement v3 → v4

Major version bumps in `Duende.AccessTokenManagement` can introduce API and behavior changes, so the exact upgrade steps depend on the released v4 surface. Below is a general migration of your code along with the areas you should double-check against the official v4 upgrade guide / release notes.

## Registration

Your registration code is largely unchanged conceptually — you still register token management and add a named client:

```csharp
services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "my-service";
        client.ClientSecret = "my-secret";
        client.Scope = "api1";
    });
```

Things to verify:
- **Caching:** confirm whether v4 still needs an explicit `IDistributedCache` registration (`AddDistributedMemoryCache()` for dev, Redis for production) or whether it now provides a default cache. Check the release notes and keep a distributed cache for multi-instance deployments.
- Confirm the property names (`TokenEndpoint`, `ClientId`, `ClientSecret`, `Scope`) still exist and haven't changed types.

## Manual token retrieval

```csharp
public class MyService
{
    private readonly IClientCredentialsTokenManagementService _tokenService;

    public MyService(IClientCredentialsTokenManagementService tokenService)
    {
        _tokenService = tokenService;
    }

    public async Task DoWork(HttpClient client)
    {
        var token = await _tokenService.GetAccessTokenAsync("api-client");
        client.SetBearerToken(token.AccessToken);
    }
}
```

Things to verify:
- Whether the returned token object still exposes `.Value` / `.AccessToken`, and whether error handling has changed (e.g. a result type indicating success/failure instead of throwing).
- Whether the injected service interface name changed.

## Recommendation

The cleanest upgrade is to move away from manual retrieval entirely and use the `IHttpClientFactory` integration — `AddClientCredentialsHttpClient(...)` or `AddHttpClient(...).AddClientCredentialsTokenHandler("api-client")` — so the library handles acquisition, caching, refresh, and attaching the bearer token automatically. That code path tends to be the most stable across versions.

Before shipping, review the official Duende v3 → v4 upgrade guide and run your integration tests, since major versions can change cache behavior, interface names, and return types.
