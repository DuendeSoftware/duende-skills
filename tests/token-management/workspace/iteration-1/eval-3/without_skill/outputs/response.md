# Upgrading Token Management v3 to v4

Here's the updated code for v4:

```csharp
services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = "my-service";
        client.ClientSecret = "my-secret";
        client.Scope = "api1";
    });
```

And the updated service:

```csharp
public class MyService
{
    private readonly IClientCredentialsTokenManagementService _tokenService;

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

Note: You may want to check the official v4 migration guide for any additional API changes.
