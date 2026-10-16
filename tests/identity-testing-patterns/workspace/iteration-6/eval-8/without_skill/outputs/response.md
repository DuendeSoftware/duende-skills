# IdentityServer integration tests failing in CI: common pitfalls

## 1. Key management writes to disk
Automatic key management stores keys in `~/keys` / a `keys` folder by default (file store), which fails on read-only or shared CI agents and leaks state between runs.

Fix – in the test host, disable it and use an in-memory signing key:
```csharp
services.AddIdentityServer(o => o.KeyManagement.Enabled = false)
        .AddDeveloperSigningCredential(persistKey: false);
// or a static key:
// .AddSigningCredential(new RsaSecurityKey(RSA.Create(2048)) { KeyId = "test" }, "RS256");
```
Alternatively keep key management but point `KeyPath` to a temp dir (`Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString())`), or `KeyManagement.SigningAlgorithms`/`StoreKeys` with an in-memory store.
Don't use `AddDeveloperSigningCredential()` with default persistence (writes `tempkey.jwk` to disk).

## 2. Port conflicts on localhost:5001
Caused by `UseUrls`, Kestrel config in `appsettings`/`launchSettings.json`, or tests starting the app via `dotnet run`. `WebApplicationFactory` uses `TestServer`, which is in-memory and needs **no port**:
- Use `WebApplicationFactory<Program>` and `factory.CreateClient()`.
- Remove hard-coded `.UseUrls("https://localhost:5001")` or guard it by environment; use `builder.UseEnvironment("Testing")`.
- If you really need a real socket, bind to port 0 (`http://127.0.0.1:0`).
- Parallel test classes each creating a factory is fine with TestServer; with real Kestrel they collide.

## 3. Issuer mismatch
TestServer's base address is `http://localhost`. Don't hardcode `https://localhost:5001` as the authority; set `options.IssuerUri` explicitly or read the issuer from the discovery document. For a *separate* API under test, use the IdentityServer factory's `Server.CreateHandler()` as backchannel handler:
```csharp
options.BackchannelHttpHandler = identityServerFactory.Server.CreateHandler();
```

## 4. HTTPS / cookie settings
Set `RequireHttpsMetadata = false` on consumers, and watch for `Secure` cookies when using `http://localhost` in browser-flow tests.

## 5. Shared state and parallelism
- Use `IClassFixture`/collection fixtures so a factory is created once.
- In-memory stores are per factory instance; don't share mutable test data across tests.
- License: IdentityServer logs a license warning in tests; harmless. Set the license key via config if desired.

## 6. Other
- Disable external dependencies (SQL, Redis) with in-memory replacements.
- Make sure `public partial class Program {}` exists.
- Set `ASPNETCORE_ENVIRONMENT=Testing` in CI so `appsettings.Development.json` isn't loaded.
- Clock skew: don't rely on `DateTime.UtcNow` equality; allow tolerance.
