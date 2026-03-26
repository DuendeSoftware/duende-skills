# In-Process IdentityServer Testing

## Factory Setup

```csharp
public class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer()
                .AddInMemoryClients(new[]
                {
                    new Client
                    {
                        ClientId = "test.client",
                        AllowedGrantTypes = GrantTypes.ClientCredentials,
                        ClientSecrets = { new Secret("secret".Sha256()) },
                        AllowedScopes = { "api1" }
                    }
                })
                .AddInMemoryApiScopes(new[]
                {
                    new ApiScope("api1")
                })
                .AddDeveloperSigningCredential();
        });
    }
}
```

## Test

```csharp
[Fact]
public async Task CanGetClientCredentialsToken()
{
    var client = _factory.CreateClient();

    var response = await client.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = "https://localhost/connect/token",
            ClientId = "test.client",
            ClientSecret = "secret",
            Scope = "api1"
        });

    Assert.False(response.IsError);
    Assert.NotEmpty(response.AccessToken);
}
```
