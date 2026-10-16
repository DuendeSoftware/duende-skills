# Common pitfalls with IdentityServer integration tests in CI

## 1. Automatic key management writes key files to disk
```csharp
// ❌ Default key management tries to persist signing keys to disk (fails/leaks state on CI agents)
services.AddIdentityServer();

// ✅ Use a static developer key in tests
services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
})
.AddDeveloperSigningCredential(persistKey: false);   // in-memory, nothing written
```
A static key also makes signatures predictable (no rotation logic in tests).

## 2. Hard-coded localhost ports (e.g. 5001) → port conflicts
`WebApplicationFactory<Program>` hosts the app in-process on `TestServer`: no socket, no port. Conflicts happen when tests use `http://localhost:5001` literals or start a real Kestrel.
```csharp
// ❌
Address = "http://localhost:5001/connect/token"

// ✅ Use the factory client's BaseAddress
var client = factory.CreateClient();
Address = new Uri(client.BaseAddress!, "connect/token").ToString()
```
Also remove/guard `UseUrls(...)` and `launchSettings` URLs when running under `UseEnvironment("Testing")`. Likewise, don't point an API's `Authority` at `https://localhost:5001`; point it at the in-process IdentityServer's handler (`BackchannelHttpHandler = idsFactory.Server.CreateHandler()`) or, for API-only tests, use a TestAuthHandler / self-signed token.

## 3. Disabling authorization to "fix" tests
Replacing policies with an allow-all handler makes every endpoint open, so you can't test 403. Use a `TestAuthHandler` instead: authorization runs normally; only the authentication source changes.

## 4. Shared mutable state with parallel execution
- A single `HttpClient`/`ClaimsProvider` shared across tests lets one test's identity bleed into another. Create a client per test or reset in `IAsyncLifetime.InitializeAsync`.
- Mutating shared static `Config` collections (e.g. the template's `Config.Clients`) causes cross-test interference under xUnit parallelism. Prefer per-test/per-factory collections.

## 5. Not waiting for IdentityServer in Aspire/full-stack tests
```csharp
await _app.StartAsync(cts.Token);
await _app.ResourceNotifications.WaitForResourceHealthyAsync("idp", cts.Token);   // ✅ before requesting tokens
```

## 6. Configuration mistakes that look like flaky failures
- **Audience mismatch** in self-signed tokens (token audience must equal API `ValidAudience`, e.g. `my-api`) → 401.
- **Missing `openid` scope** for interactive clients → no ID token.
- **Issuer mismatch:** the in-process issuer is the TestServer address (`https://localhost`), not `:5001`.

## Recommended baseline test host
```csharp
public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer(o => { o.KeyManagement.Enabled = false; })
                .AddInMemoryClients(TestConfig.Clients)
                .AddInMemoryApiScopes(TestConfig.ApiScopes)
                .AddInMemoryApiResources(TestConfig.ApiResources)
                .AddInMemoryIdentityResources(TestConfig.IdentityResources)
                .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```
