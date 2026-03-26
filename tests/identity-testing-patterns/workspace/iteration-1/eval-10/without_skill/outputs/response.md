# Minimal In-Process IdentityServer for Testing

```csharp
public class TestIdentityServerFactory : WebApplicationFactory<Program>
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
                        ClientId = "test",
                        AllowedGrantTypes = GrantTypes.ClientCredentials,
                        ClientSecrets = { new Secret("secret".Sha256()) },
                        AllowedScopes = { "api" }
                    }
                })
                .AddInMemoryApiScopes(new[] { new ApiScope("api") })
                .AddDeveloperSigningCredential();
        });
    }
}
```

This creates a minimal IdentityServer in the test process that can issue tokens without a real server.
