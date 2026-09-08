# Adding an Integration-Test Project for a `duende-is-inmem` Host

You want to test the **real** IdentityServer host (its actual endpoints and token issuance), not a mocked API. That means the test project must run the host in-process with `WebApplicationFactory<Program>`, so it needs the ASP.NET Core **Web SDK** and the MVC testing + IdentityModel packages.

## 1. Change the test project SDK to the Web SDK

`WebApplicationFactory<T>` resolves the host's web dependencies, so the test project can't use the plain `Microsoft.NET.Sdk`:

```xml
<!-- ❌ Default test project SDK -->
<Project Sdk="Microsoft.NET.Sdk">

<!-- ✅ Web SDK — required to host the IdentityServer web app under test -->
<Project Sdk="Microsoft.NET.Sdk.Web">
```

## 2. Add the required packages + a project reference to the host

```xml
<ItemGroup>
  <!-- WebApplicationFactory<T> -->
  <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="*" />
  <!-- OIDC/OAuth client helpers: GetDiscoveryDocumentAsync, RequestClientCredentialsTokenAsync -->
  <PackageReference Include="Duende.IdentityModel" Version="*" />

  <PackageReference Include="xunit" Version="*" />
  <PackageReference Include="xunit.runner.visualstudio" Version="*" />
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="*" />
</ItemGroup>

<ItemGroup>
  <!-- Reference the scaffolded host so Program is visible to WebApplicationFactory<Program> -->
  <ProjectReference Include="..\IdentityServerHost\IdentityServerHost.csproj" />
</ItemGroup>
```

## 3. The test class

```csharp
using Duende.IdentityModel.Client;   // discovery + token helpers
using Microsoft.AspNetCore.Mvc.Testing;

public class IdentityServerTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    // factory.CreateClient() serves the host over https on the in-memory server
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Discovery_document_is_available()
    {
        var disco = await _client.GetDiscoveryDocumentAsync();
        Assert.False(disco.IsError);
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

        Assert.False(token.IsError);
        Assert.NotNull(token.AccessToken);
    }
}
```

`GetDiscoveryDocumentAsync` and `RequestClientCredentialsTokenAsync` (from **`Duende.IdentityModel`**) hit the host's real `/.well-known/openid-configuration` and `/connect/token`. The discovery test asserts `disco.IsError` is `false`; the token test targets `connect/token` and asserts the token is not an error.

## Caution: parallel tests and shared static config

The template exposes its clients/scopes as static `Config` collections. If a test **mutates** those shared statics (adding/clearing clients or scopes), xUnit's parallel execution can let one test's changes bleed into another, causing intermittent, order-dependent failures. Prefer per-test collections or a fresh factory per test over mutating the shared static `Config`.
