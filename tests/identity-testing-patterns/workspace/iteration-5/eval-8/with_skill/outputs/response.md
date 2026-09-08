# Common IdentityServer Integration-Test Pitfalls in CI (and Fixes)

Your two symptoms — key files being written to disk and port conflicts on `localhost:5001` — are the two classic mistakes. Here's how to fix them, plus a couple of related traps.

## 1. Automatic key management writing key files to disk

By default IdentityServer's automatic key management generates and **persists signing keys to disk** and rotates them. In CI this causes file-permission failures, flaky first-run behavior, and non-deterministic signatures.

**Fix:** disable automatic key management and use a static developer signing key that is *not* persisted:

```csharp
services.AddIdentityServer(options =>
{
    // ✅ Stop IdentityServer from managing/writing keys to disk
    options.KeyManagement.Enabled = false;
})
.AddInMemoryClients(TestConfig.Clients)
.AddInMemoryApiScopes(TestConfig.ApiScopes)
// ✅ Static dev key held in memory, never written to disk
.AddDeveloperSigningCredential(persistKey: false);
```

- `options.KeyManagement.Enabled = false` turns off the automatic key store/rotation that does the disk writes.
- `AddDeveloperSigningCredential(persistKey: false)` supplies a fixed signing key for the test run without creating a `tempkey.jwk` file. (The default overload *does* persist to disk — always pass `persistKey: false` in tests.)

## 2. Hard-coded `localhost:5001` port conflicts

The `WebApplicationFactory` in-memory server does **not** listen on a real TCP port, so any hard-coded `http://localhost:5001/...` address is both wrong and a source of conflicts when something else grabs the port.

**Fix:** never hard-code ports. Use the client the factory hands you — its `BaseAddress` already points at the test server:

```csharp
// ❌ WRONG
Address = "http://localhost:5001/connect/token"

// ✅ CORRECT
_client = factory.CreateClient(); // BaseAddress set by the factory
var tokenRequest = new ClientCredentialsTokenRequest
{
    Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
    // ...
};
```

## 3. Shared HttpClient / mutable test state across parallel tests

xUnit runs test classes in parallel by default. If you share a single static `HttpClient`, a `TestClaimsProvider`, or mutate shared static `Config` collections, identity/state set by one test can **bleed into another**, producing intermittent failures that look random.

**Fix:**
- Create a fresh `HttpClient` per test (or per class) rather than one static shared instance.
- Reset any per-test identity state (e.g. `ClaimsProvider.ClearClaims()`) in `IAsyncLifetime.InitializeAsync`.
- Prefer per-test client/scope collections over mutating shared static `Config` lists.

```csharp
public async Task InitializeAsync()
{
    _factory.ClaimsProvider.ClearClaims();
    await Task.CompletedTask;
}
```

## Summary
| Symptom | Cause | Fix |
|---|---|---|
| Key files written in CI | Automatic key management | `KeyManagement.Enabled = false` + `AddDeveloperSigningCredential(persistKey: false)` |
| Port conflicts on 5001 | Hard-coded localhost address | Use `factory.CreateClient()` `BaseAddress` |
| Random cross-test failures | Shared `HttpClient` / mutable shared state | Fresh client + reset provider per test |
