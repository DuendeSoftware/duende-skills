# Minimal In-Process IdentityServer for Testing

The minimal pattern for hosting IdentityServer in-process:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer(options =>
            {
                // Disable key management — no disk writes in CI
                options.KeyManagement.Enabled = false;
            })
            .AddInMemoryClients(new[]
            {
                new Client
                {
                    ClientId = "test.service",
                    AllowedGrantTypes = GrantTypes.ClientCredentials,
                    ClientSecrets = { new Secret("test-secret".Sha256()) },
                    AllowedScopes = { "api1" }
                }
            })
            .AddInMemoryApiScopes(new[]
            {
                new ApiScope("api1")
            })
            .AddInMemoryIdentityResources(new IdentityResource[]
            {
                new IdentityResources.OpenId()
            })
            // Static signing key — in-memory only, no persistence
            .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```

## Key Elements

1. **`WebApplicationFactory<Program>`** — Hosts the full ASP.NET Core pipeline in-process using `TestServer`
2. **`ConfigureTestServices`** — Overrides the production DI registration to inject test configuration
3. **`KeyManagement.Enabled = false`** — Prevents the automatic key management background service from trying to generate and persist keys to disk
4. **`AddDeveloperSigningCredential(persistKey: false)`** — Creates a temporary RSA signing key in memory, valid only for the lifetime of the test process
5. **`AddInMemoryClients`** — Registers test clients without needing a database or configuration store

This pattern gives you a fully functional IdentityServer that can issue tokens, validate them, and respond to discovery requests — all within the test process with zero external dependencies.
