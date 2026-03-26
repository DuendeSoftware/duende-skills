# Common IdentityServer Integration Test Pitfalls in CI

## 1. Key Management Writes to Disk

**Problem:** Automatic key management tries to create and write signing key files to disk. In CI containers, the default path may not be writable.

**Fix:** Disable automatic key management in tests:

```csharp
services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
})
.AddDeveloperSigningCredential(persistKey: false);
```

- `KeyManagement.Enabled = false` — prevents the key management system from running entirely
- `AddDeveloperSigningCredential(persistKey: false)` — creates an in-memory RSA key without writing `tempkey.jwk` to disk

## 2. Port Conflicts with localhost:5001

**Problem:** Hard-coding `https://localhost:5001` in token requests causes port conflicts when multiple test suites run in parallel, or when another process is already using port 5001.

**Fix:** Use `factory.CreateClient()` and its `BaseAddress`:

```csharp
// ❌ Hard-coded port — causes conflicts in CI
var request = new ClientCredentialsTokenRequest
{
    Address = "https://localhost:5001/connect/token"
};

// ✅ Use the factory's base address
var client = factory.CreateClient();
var request = new ClientCredentialsTokenRequest
{
    Address = new Uri(client.BaseAddress!, "connect/token").ToString()
};
```

`WebApplicationFactory` creates an in-memory `TestServer` with its own base address. No network port is opened.

## 3. Shared HttpClient and ClaimsProvider State

**Problem:** When using `TestAuthHandler` with a shared `TestClaimsProvider`, parallel test execution causes one test's claims to bleed into another test.

**Fix:**
- Reset the `ClaimsProvider` between tests using `IAsyncLifetime`:
```csharp
public async Task InitializeAsync()
{
    _factory.ClaimsProvider.ClearClaims();
    await Task.CompletedTask;
}
```
- Or create a new `HttpClient` per test if needed.
- Consider using `[Collection("...")]` to serialize tests that share mutable state.

## 4. Missing `persistKey: false` on Developer Signing Credential

**Problem:** `AddDeveloperSigningCredential()` without `persistKey: false` writes a `tempkey.jwk` file to the current directory. In CI, this can fail if the working directory is read-only, or cause conflicts between parallel test runs.

**Fix:** Always pass `persistKey: false` in test configurations:

```csharp
.AddDeveloperSigningCredential(persistKey: false)
```

## Summary

| Pitfall | Fix |
|---------|-----|
| Key management disk writes | `KeyManagement.Enabled = false` |
| Developer key persistence | `AddDeveloperSigningCredential(persistKey: false)` |
| Port conflicts | Use `factory.CreateClient().BaseAddress` |
| Shared test state | Reset `ClaimsProvider` per test; use `IAsyncLifetime` |
