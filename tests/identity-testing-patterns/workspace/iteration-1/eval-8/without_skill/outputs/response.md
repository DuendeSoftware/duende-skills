# Fixing IdentityServer Integration Test Failures in CI

## Key Management Issues

IdentityServer tries to create and persist signing keys to disk. In CI environments, this may fail due to read-only filesystems or permission issues.

**Solution:** Use a developer signing credential that doesn't persist:

```csharp
services.AddIdentityServer()
    .AddDeveloperSigningCredential();
```

You might also consider configuring key storage to a writable location in CI.

## Port Conflicts

If your tests are configured to use `localhost:5001`, you'll get port conflicts when multiple tests run simultaneously.

**Solution:** Use `WebApplicationFactory` which creates an in-memory test server that doesn't bind to a real port:

```csharp
var client = factory.CreateClient();
// The client.BaseAddress is already configured correctly
```

Avoid hard-coding URLs like `http://localhost:5001` in your test code.

## General Tips

- Make sure your test configuration is separate from production configuration
- Use `WebApplicationFactory<Program>` for integration tests
- Consider using xUnit's collection fixtures to share expensive setup between tests
- Be careful with static state that can leak between tests
