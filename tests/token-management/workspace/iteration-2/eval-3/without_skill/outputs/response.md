# Upgrading Token Management from v3 to v4

Here's how to update your Duende.AccessTokenManagement code from v3 to v4.

## Updated Registration

```csharp
services.AddDistributedMemoryCache();
services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "my-service";
        client.ClientSecret = "my-secret";
        client.Scope = "api1";
    });
```

## Updated Service

```csharp
public class MyService
{
    private readonly IClientCredentialsTokenManagementService _tokenService;

    public MyService(IClientCredentialsTokenManagementService tokenService)
    {
        _tokenService = tokenService;
    }

    public async Task DoWork()
    {
        var token = await _tokenService.GetAccessTokenAsync("api-client");
        if (token != null && !string.IsNullOrEmpty(token.AccessToken))
        {
            client.SetBearerToken(token.AccessToken);
        }
    }
}
```

## Notes

- The basic pattern remains the same between v3 and v4 — you register clients and use the token service to get tokens.
- Check the Duende documentation for any breaking changes in the v4 upgrade.
- Make sure you update the NuGet package to the v4 version.
- The `AddDistributedMemoryCache()` registration is still needed for token caching.
