# Minimal in-process IdentityServer for integration tests

Use `WebApplicationFactory<Program>` on your IdentityServer host (it runs on `TestServer`, no ports). Minimum ingredients: in-memory config, an in-memory signing key (no disk), and the host's `Program` made visible.

```csharp
// IdentityServer host
public partial class Program { }
```

```csharp
public class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureServices(services =>
        {
            services.AddIdentityServer(o => o.KeyManagement.Enabled = false)
                .AddInMemoryApiScopes(new[] { new ApiScope("api1") })
                .AddInMemoryClients(new[]
                {
                    new Client
                    {
                        ClientId = "test",
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

Test:
```csharp
public class SmokeTests(IdentityServerFactory factory) : IClassFixture<IdentityServerFactory>
{
    [Fact]
    public async Task Discovery_works()
    {
        var client = factory.CreateClient();
        var disco = await client.GetDiscoveryDocumentAsync();
        Assert.False(disco.IsError, disco.Error);
    }
}
```

Key points:
1. `WebApplicationFactory` → in-memory server, no port conflicts.
2. Disable automatic key management / don't persist keys.
3. In-memory clients/scopes/resources.
4. Use `factory.Server.CreateHandler()` as `BackchannelHttpHandler` when an API under test must fetch discovery/JWKS from it.
5. Share the factory via `IClassFixture`.
