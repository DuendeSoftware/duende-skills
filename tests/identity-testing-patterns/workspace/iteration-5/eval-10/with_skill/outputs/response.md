# Minimal In-Process IdentityServer for Integration Testing

The smallest reliable pattern is a `WebApplicationFactory<Program>` that uses `ConfigureTestServices` to override IdentityServer's registration with a static signing key, disabled key management, and in-memory clients/scopes.

```csharp
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        // ✅ ConfigureTestServices overrides run AFTER the app's own registrations
        builder.ConfigureTestServices(services =>
        {
            // Replace the app's IdentityServer options cleanly
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<IdentityServerOptions>));
            if (descriptor is not null)
                services.Remove(descriptor);

            services.AddIdentityServer(options =>
                {
                    // ✅ No automatic key management => no key files written in CI
                    options.KeyManagement.Enabled = false;
                })
                .AddInMemoryClients(TestClients)
                .AddInMemoryApiScopes(TestScopes)
                // ✅ Static developer signing key, not persisted to disk
                .AddDeveloperSigningCredential(persistKey: false);
        });
    }

    private static IEnumerable<Client> TestClients =>
    [
        new Client
        {
            ClientId = "m2m.client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    ];

    private static IEnumerable<ApiScope> TestScopes =>
    [
        new ApiScope("api1", "Test API")
    ];
}
```

## The three things that make it work
1. **`WebApplicationFactory<Program>` + `ConfigureTestServices`** — hosts the real IdentityServer in-process and lets you override its registration after the app has configured itself, so your test clients/keys win.
2. **`options.KeyManagement.Enabled = false`** — disables automatic key rotation/persistence, which otherwise writes key files to disk and flakes in CI.
3. **`AddDeveloperSigningCredential(persistKey: false)`** — supplies a fixed, in-memory signing key so token signatures are deterministic and nothing touches the filesystem.

In-memory clients/scopes are registered with **`AddInMemoryClients`** (and `AddInMemoryApiScopes`), keeping configuration inside the test with no database.

That's the complete minimal core — this pattern alone (no sub-documents) is enough to host IdentityServer under test and hit `/connect/token`.
