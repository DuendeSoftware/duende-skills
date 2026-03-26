# Upgrading Token Management v3 to v4

## Updated Code

```csharp
// Registration (v4)
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

    public async Task DoWork()
    {
        var token = await _tokenService.GetAccessTokenAsync("api-client");
        client.SetBearerToken(token.AccessToken);
    }
}
```

Check the Duende documentation for any breaking changes between v3 and v4.
