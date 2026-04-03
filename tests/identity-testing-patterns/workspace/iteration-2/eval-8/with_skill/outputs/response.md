# Common Pitfalls in IdentityServer Integration Testing

Here are the common pitfalls causing CI failures and how to fix them.

## 1. Key Management Tries to Write to Disk

**Problem:** Automatic key management attempts to persist key material to disk, which fails in CI environments with read-only file systems or ephemeral containers.

**Fix:** Disable automatic key management and use a static development signing key:

```csharp
services.AddIdentityServer(options =>
{
    // Disable automatic key management — no disk writes
    options.KeyManagement.Enabled = false;
})
// Static development signing key — not persisted to disk
.AddDeveloperSigningCredential(persistKey: false);
```

## 2. Port Conflicts with Hard-Coded localhost:5001

**Problem:** Hard-coding `http://localhost:5001` in test token requests causes port conflicts when multiple test hosts run simultaneously in CI.

**Fix:** Use `factory.CreateClient()` and its `BaseAddress` instead of hard-coded ports:

```csharp
// WRONG — Port conflicts in CI
new ClientCredentialsTokenRequest
{
    Address = "http://localhost:5001/connect/token",
    ...
}

// CORRECT — Use the factory client's BaseAddress
var client = factory.CreateClient();
new ClientCredentialsTokenRequest
{
    Address = new Uri(client.BaseAddress!, "connect/token").ToString(),
    ...
}
```

The `WebApplicationFactory` assigns a random port via the in-memory test server, avoiding conflicts entirely.

## 3. Sharing HttpClient / ClaimsProvider State Across Tests

**Problem:** When using `TestAuthHandler` with a shared `TestClaimsProvider`, claims set in one test bleed into another test running in parallel. This causes non-deterministic failures.

**Fix:** Reset the `ClaimsProvider` at the start of each test (or in `IAsyncLifetime.InitializeAsync`), and avoid sharing a single `HttpClient` instance across tests:

```csharp
public class MyTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly ApiFactory _factory;

    public async Task InitializeAsync()
    {
        _factory.ClaimsProvider.ClearClaims();
        await Task.CompletedTask;
    }

    public Task DisposeAsync() => Task.CompletedTask;
}
```

## 4. Summary

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Key management enabled in tests | File access errors in CI | `options.KeyManagement.Enabled = false` |
| No static signing key | `InvalidOperationException` on token signing | `.AddDeveloperSigningCredential(persistKey: false)` |
| Hard-coded localhost port | Connection refused / port already in use | Use `factory.CreateClient().BaseAddress` |
| Shared ClaimsProvider state | Intermittent test failures | Reset claims in `InitializeAsync`, create fresh client per test |
