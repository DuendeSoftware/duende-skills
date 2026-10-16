# Integration tests for a `duende-is-inmem` host

The point here is to test IdentityServer's **real** endpoints (no auth mocking), unlike `TestAuthHandler` patterns that fake auth for a downstream API.

## 1. Test `.csproj` changes

**Use the Web SDK** so ASP.NET Core testing APIs resolve against the web host:
```xml
<!-- ❌ Default test project SDK -->
<Project Sdk="Microsoft.NET.Sdk">

<!-- ✅ Web SDK — required for WebApplicationFactory<T> against a web host -->
<Project Sdk="Microsoft.NET.Sdk.Web">
```

Add packages and the project reference:
```xml
<ItemGroup>
  <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="*" /> <!-- WebApplicationFactory<T> -->
  <PackageReference Include="Duende.IdentityModel" Version="*" />            <!-- discovery/token helpers -->
  <PackageReference Include="xunit" Version="*" />
  <PackageReference Include="xunit.runner.visualstudio" Version="*" />
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="*" />
</ItemGroup>

<ItemGroup>
  <ProjectReference Include="..\IdentityServerHost\IdentityServerHost.csproj" />
</ItemGroup>
```

## 2. Host changes
- Make `Program` visible to the test project: add `public partial class Program { }` to the host's `Program.cs` (the template uses top-level statements).
- Optionally make the template's static `Config` collections mutable (`public static List<Client> Clients = [...]`, same for `ApiScopes`, `IdentityResources`) so tests can add/clear entries. Caution: under xUnit's parallel execution, mutating shared statics causes cross-test interference. Prefer per-test collections or a fresh factory per test.
- If you hit key-file or CI problems, disable automatic key management in a test factory (`KeyManagement.Enabled = false` + `AddDeveloperSigningCredential(persistKey: false)`).

## 3. The tests
```csharp
using Duende.IdentityModel.Client;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public class IdentityServerTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    // factory.CreateClient() serves the host over https on localhost
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Discovery_document_is_available()
    {
        var disco = await _client.GetDiscoveryDocumentAsync();
        Assert.False(disco.IsError, disco.Error);
    }

    [Fact]
    public async Task Can_request_client_credentials_token()
    {
        var token = await _client.RequestClientCredentialsTokenAsync(new()
        {
            Address = "connect/token",
            ClientId = "m2m.client",
            ClientSecret = "secret",
            Scope = "api1"
        });

        Assert.False(token.IsError, token.Error);
        Assert.NotNull(token.AccessToken);
    }

    [Fact]
    public void Can_resolve_in_process_services()
    {
        // Reach into the running host's DI container
        using var scope = factory.Services.CreateScope();
        var profileService = scope.ServiceProvider.GetRequiredService<IProfileService>();
        Assert.NotNull(profileService);
    }
}
```
`GetDiscoveryDocumentAsync` and `RequestClientCredentialsTokenAsync` come from `Duende.IdentityModel`. Use the client id/secret/scope your scaffolded `Config.cs` defines (the template's machine-to-machine client is `m2m.client` / `secret` with scope `api1`). `factory.Services` lets you assert on real in-process services (profile service, stores, options).

(The `Program.cs` you pasted is a protected Web API, not the IdentityServer host. The test project must reference the IdentityServer host project.)
