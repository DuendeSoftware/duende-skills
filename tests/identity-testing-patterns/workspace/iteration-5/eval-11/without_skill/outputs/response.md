# Integration-Testing a Scaffolded IdentityServer Host

To test the real IdentityServer host in-process, your test project needs to host the web app with `WebApplicationFactory<Program>`. That requires switching the test project to the ASP.NET Core Web SDK and adding the testing and IdentityModel client packages, plus a reference to the host.

## 1. Change the test project SDK

A default test project uses `Microsoft.NET.Sdk`, but hosting a web app under `WebApplicationFactory<T>` needs the Web SDK:

```xml
<!-- Before -->
<Project Sdk="Microsoft.NET.Sdk">

<!-- After -->
<Project Sdk="Microsoft.NET.Sdk.Web">
```

## 2. Add packages and a project reference

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="*" />
  <PackageReference Include="Duende.IdentityModel" Version="*" />
  <PackageReference Include="xunit" Version="*" />
  <PackageReference Include="xunit.runner.visualstudio" Version="*" />
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="*" />
</ItemGroup>

<ItemGroup>
  <ProjectReference Include="..\IdentityServerHost\IdentityServerHost.csproj" />
</ItemGroup>
```

- `Microsoft.AspNetCore.Mvc.Testing` provides `WebApplicationFactory<T>`.
- `Duende.IdentityModel` provides the OIDC/OAuth client helpers (`GetDiscoveryDocumentAsync`, `RequestClientCredentialsTokenAsync`).

## 3. The test

```csharp
using Duende.IdentityModel.Client;
using Microsoft.AspNetCore.Mvc.Testing;

public class IdentityServerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public IdentityServerTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Discovery_document_is_available()
    {
        var disco = await _client.GetDiscoveryDocumentAsync();
        Assert.False(disco.IsError);
    }

    [Fact]
    public async Task Can_request_a_client_credentials_token()
    {
        var token = await _client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
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

## Notes
- `IClassFixture<WebApplicationFactory<Program>>` shares a single host across the test class, and `factory.CreateClient()` gives you a client bound to the in-memory server.
- The discovery test asserts `disco.IsError` is `false`; the token test hits `connect/token` and asserts the token is not an error.
- Match the `ClientId`/`ClientSecret`/`Scope` to whatever the template's `Config` defines (the default in-memory template ships an `m2m.client` with an `api1` scope).
