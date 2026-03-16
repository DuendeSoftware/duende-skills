# Common CI Pitfalls for IdentityServer Integration Tests

## 1. Key Management Writes to Disk

The most common CI failure. IdentityServer's automatic key management tries to persist signing keys to the file system, which fails in ephemeral CI environments.

**Fix:** Disable automatic key management and use a non-persisted developer signing key:

```csharp
services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
})
.AddDeveloperSigningCredential(persistKey: false);
```

- `options.KeyManagement.Enabled = false` prevents automatic key rotation.
- `AddDeveloperSigningCredential(persistKey: false)` generates a static in-memory key on each test run — no disk writes.

## 2. Port Conflicts with localhost:5001

Hard-coding `localhost:5001` in test token requests causes port conflicts in CI where multiple agents run simultaneously.

**Fix:** Use `factory.CreateClient()` and its `BaseAddress`:

```csharp
// ❌ WRONG — Port conflicts in CI
new ClientCredentialsTokenRequest
{
    Address = "http://localhost:5001/connect/token",
};

// ✅ CORRECT — Use the factory's base address
var client = factory.CreateClient();
new ClientCredentialsTokenRequest
{
    Address = new Uri(client.BaseAddress!, "connect/token").ToString(),
};
```

`WebApplicationFactory` uses an in-memory test server — there is no real TCP port binding. The `BaseAddress` property provides the correct URL.

## 3. Shared State Across Parallel Tests

If tests share an `HttpClient` or a `TestClaimsProvider` instance, claims set in one test can bleed into another running in parallel.

**Fix:**
- Create a fresh `HttpClient` per test or per test class.
- Reset the `ClaimsProvider` at the start of each test (e.g., in an `IAsyncLifetime.InitializeAsync`):

```csharp
public async Task InitializeAsync()
{
    _factory.ClaimsProvider.ClearClaims();
    await Task.CompletedTask;
}
```

## 4. Missing Test Environment Configuration

If your `Program.cs` reads configuration that doesn't exist in the test environment (like `Authentication:Authority`), requests may fail with discovery errors.

**Fix:** Override the relevant services in `ConfigureTestServices` rather than relying on appsettings.

## Summary

| Issue | Fix |
|-------|-----|
| Key management disk writes | `options.KeyManagement.Enabled = false` + `AddDeveloperSigningCredential(persistKey: false)` |
| Port conflicts | Use `factory.CreateClient().BaseAddress` |
| Shared state | Reset `ClaimsProvider` per test, don't share `HttpClient` |
| Config mismatches | Override in `ConfigureTestServices` |
