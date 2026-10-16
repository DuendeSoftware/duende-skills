# Upgrading v3 → v4

Main changes: strongly typed values (`ClientId`, `ClientSecret`, `Scope`, `Uri` endpoint), `HybridCache` replaces `IDistributedCache` as the cache abstraction, and `IClientCredentialsTokenManagementService` is replaced by `IClientCredentialsTokenManager`, which returns a result type.

## Registration

```csharp
// no AddDistributedMemoryCache needed; HybridCache is used (in-memory by default)
services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });
```

If you want a shared L2 cache, register a distributed cache (e.g. Redis) and it plugs into HybridCache.

## Manual retrieval

```csharp
public class MyService(IClientCredentialsTokenManager tokenManager, HttpClient client)
{
    public async Task DoWork(CancellationToken ct)
    {
        var result = await tokenManager.GetAccessTokenAsync(
            ClientCredentialsClientName.Parse("api-client"), ct: ct);

        if (!result.WasSuccessful(out var token, out var failure))
            throw new InvalidOperationException($"Token failed: {failure.Error}");

        client.SetBearerToken(token.AccessToken.ToString());
        // ...
    }
}
```

## Preferred: don't fetch manually

```csharp
services.AddClientCredentialsHttpClient("api", ClientCredentialsClientName.Parse("api-client"),
    c => c.BaseAddress = new Uri("https://api.example.com/"));
```
Then use `IHttpClientFactory.CreateClient("api")` – the token is attached automatically.
