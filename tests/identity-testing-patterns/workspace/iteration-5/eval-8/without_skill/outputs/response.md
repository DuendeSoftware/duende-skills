# Fixing Flaky IdentityServer Integration Tests in CI

The two problems you describe — key files being written to disk and port conflicts on `localhost:5001` — are common when integration tests aren't configured for a headless CI environment. Here's how to address them.

## 1. Key management writing files to disk

Duende IdentityServer's default key management creates and rotates signing keys, persisting them to the file system. On a CI agent this often fails (no writable location, ephemeral containers) or produces non-deterministic behavior.

**Fix:** use a fixed developer signing credential for tests instead of automatic key management:

```csharp
services.AddIdentityServer()
    .AddInMemoryClients(TestConfig.Clients)
    .AddInMemoryApiScopes(TestConfig.ApiScopes)
    // Fixed signing key for tests; don't persist a key file to disk
    .AddDeveloperSigningCredential(persistKey: false);
```

Passing `persistKey: false` prevents the `tempkey.jwk` file from being written, which removes the disk-write problem. A static signing credential also keeps token signatures predictable across runs.

## 2. Port conflicts on localhost:5001

Hard-coding a URL like `https://localhost:5001/connect/token` is the usual cause. When you use `WebApplicationFactory`, the test host is in-memory and does not bind a physical port — so a hard-coded port is both incorrect and prone to clashing with other processes.

**Fix:** get the address from the factory's client rather than hard-coding it:

```csharp
var client = factory.CreateClient(); // BaseAddress points at the in-memory test server

var token = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
{
    Address = new Uri(client.BaseAddress!, "connect/token").ToString(),
    ClientId = "test-client",
    ClientSecret = "secret",
    Scope = "api1"
});
```

## 3. Other things to check
- Make sure the test host uses a dedicated environment (e.g. `builder.UseEnvironment("Testing")`) so it doesn't pick up production HTTPS/port settings.
- If you disable HTTPS redirection or metadata requirements only in production config, ensure the test configuration matches.
- Run tests against the in-memory handler (`factory.CreateClient()`), not a Kestrel instance bound to a real port.

## Summary
- Replace automatic key management with `AddDeveloperSigningCredential(persistKey: false)` to stop disk writes and get deterministic signatures.
- Never hard-code `localhost:5001`; use `factory.CreateClient()` and its `BaseAddress`.
- Use a dedicated test environment so production port/HTTPS settings don't leak into tests.
