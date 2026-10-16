# In-process IdentityServer with WebApplicationFactory

Your `Program.cs` is a *protected API*, not an IdentityServer, so the cleanest approach is a separate IdentityServer host project (or a test-local host) that exposes a `Program` class. Below I assume an IdentityServer host project `IdentityServerHost` with `public partial class Program {}`.

## Test project csproj
```xml
<ItemGroup>
  <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.0" />
  <PackageReference Include="Duende.IdentityModel" Version="7.*" />
  <PackageReference Include="xunit" Version="2.*" />
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
</ItemGroup>
<ItemGroup>
  <ProjectReference Include="..\IdentityServerHost\IdentityServerHost.csproj" />
</ItemGroup>
```

## Factory
```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureServices(services =>
        {
            services.AddIdentityServer(o =>
            {
                o.KeyManagement.Enabled = false;   // don't write keys to disk
            })
            .AddInMemoryApiScopes(new[] { new ApiScope("api1") })
            .AddInMemoryClients(new[]
            {
                new Client
                {
                    ClientId = "test-client",
                    ClientSecrets = { new Secret("secret".Sha256()) },
                    AllowedGrantTypes = GrantTypes.ClientCredentials,
                    AllowedScopes = { "api1" }
                }
            })
            .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```
If the host project already calls `AddIdentityServer`, calling it again in the test adds duplicates; better to have the host read clients from configuration, or register test clients with `services.AddSingleton<IClientStore>(...)` overriding the store, or use `IdentityServerBuilder` conditionally on environment. Using `AddInMemoryClients` a second time simply adds a second store, so be aware of this.

## Test
```csharp
using Duende.IdentityModel.Client;

public class TokenTests : IClassFixture<IdentityServerFactory>
{
    private readonly IdentityServerFactory _factory;
    public TokenTests(IdentityServerFactory f) => _factory = f;

    [Fact]
    public async Task Client_credentials_returns_access_token()
    {
        var client = _factory.CreateClient();   // HttpClient wired to the TestServer

        var disco = await client.GetDiscoveryDocumentAsync();
        Assert.False(disco.IsError, disco.Error);

        var token = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint,
            ClientId = "test-client",
            ClientSecret = "secret",
            Scope = "api1"
        });

        Assert.False(token.IsError, token.Error);
        Assert.False(string.IsNullOrEmpty(token.AccessToken));
        Assert.Equal("Bearer", token.TokenType);
        Assert.True(token.ExpiresIn > 0);
    }

    [Fact]
    public async Task Wrong_secret_fails()
    {
        var client = _factory.CreateClient();
        var token = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = "connect/token",
            ClientId = "test-client",
            ClientSecret = "wrong",
            Scope = "api1"
        });
        Assert.True(token.IsError);
        Assert.Equal("invalid_client", token.Error);
    }
}
```
The discovery document's issuer will be `http://localhost` (the TestServer base address), and `GetDiscoveryDocumentAsync` may need `DiscoveryPolicy` adjustments if the authority differs from the request host.

Tips: use `client.PostAsync("connect/token", new FormUrlEncodedContent(...))` if you prefer not to use Duende.IdentityModel.
