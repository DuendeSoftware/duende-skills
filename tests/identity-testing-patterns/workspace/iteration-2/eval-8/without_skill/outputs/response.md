# Common IdentityServer Integration Test Pitfalls

## Key Management Disk Writes

The most common issue is that IdentityServer's key management tries to persist signing keys to disk. In CI environments this fails because the file system may be read-only or ephemeral.

**Fix:** Use a development signing credential instead of automatic key management:

```csharp
services.AddIdentityServer()
    .AddDeveloperSigningCredential();
```

This generates an in-memory signing key that doesn't need disk access.

## Port Conflicts

If you're hard-coding `localhost:5001` in your test requests, you'll get port conflicts when multiple tests run simultaneously.

**Fix:** Use `WebApplicationFactory.CreateClient()` which handles port allocation automatically:

```csharp
var client = factory.CreateClient();
// Use client.BaseAddress instead of hard-coded URLs
```

## Shared State Between Tests

When using static properties or shared `HttpClient` instances, state from one test can leak into another. This is especially problematic with parallel test execution.

**Fix:** Create fresh HttpClient instances per test and reset any shared state in test setup.

## Summary

| Issue | Fix |
|-------|-----|
| Key files written to disk | Use `AddDeveloperSigningCredential()` |
| Port conflicts | Use `factory.CreateClient()` BaseAddress |
| Shared test state | Isolate per-test, reset in setup |
