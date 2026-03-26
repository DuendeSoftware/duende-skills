# Common Integration Test Pitfalls

## Port Conflicts

Don't hard-code ports like `localhost:5001`. Use the factory's `CreateClient()` method which gives you an HttpClient with the correct base address.

```csharp
var client = factory.CreateClient();
// client.BaseAddress is set to the test server
```

## Key Files in CI

If you're using `AddDeveloperSigningCredential()`, it writes a key file to disk. In CI, you may want to use an in-memory approach.

## Shared State

Be careful about sharing HttpClient instances across tests. State can bleed between tests if you're not careful with setup/teardown.

Consider using `IAsyncLifetime` to reset state between tests.
