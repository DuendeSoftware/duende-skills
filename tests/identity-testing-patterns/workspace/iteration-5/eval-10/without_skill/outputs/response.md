# Minimal In-Process IdentityServer for Integration Testing

The core pattern is a `WebApplicationFactory<Program>` that overrides the IdentityServer registration in `ConfigureTestServices`, uses a fixed developer signing key, and registers in-memory clients and scopes.

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer()
                .AddInMemoryClients(new[]
                {
                    new Client
                    {
                        ClientId = "m2m.client",
                        ClientSecrets = { new Secret("secret".Sha256()) },
                        AllowedGrantTypes = GrantTypes.ClientCredentials,
                        AllowedScopes = { "api1" }
                    }
                })
                .AddInMemoryApiScopes(new[] { new ApiScope("api1") })
                .AddDeveloperSigningCredential();
        });
    }
}
```

Then a client can be created with `factory.CreateClient()` to hit `/connect/token`.

## Key elements
- **`WebApplicationFactory<Program>`** hosts the real app in-memory, and **`ConfigureTestServices`** lets you override the IdentityServer registration for the test run.
- **`AddInMemoryClients` / `AddInMemoryApiScopes`** register test clients and scopes without any database.
- **`AddDeveloperSigningCredential()`** provides a signing key for issuing tokens in tests.
- Using `factory.CreateClient()` routes requests to the in-memory test server rather than a bound port.

This is enough to request tokens against the in-process server in a test. For CI stability you may also want to ensure the developer signing key isn't persisted between runs and that key management doesn't attempt disk writes.
