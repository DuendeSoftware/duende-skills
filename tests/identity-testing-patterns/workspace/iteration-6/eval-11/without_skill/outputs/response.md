# Integration test project for a `duende-is-inmem` host

## Test .csproj
Key changes: use the Web SDK-compatible testing package, reference the host project, and reference the host's framework (the host is `Microsoft.NET.Sdk.Web`, so the test project needs the ASP.NET Core shared framework).

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
    <PackageReference Include="xunit" Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.0" />
    <PackageReference Include="Duende.IdentityModel" Version="7.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\IdentityServer\IdentityServer.csproj" />
  </ItemGroup>

</Project>
```
(Alternatively set `<Project Sdk="Microsoft.NET.Sdk.Web">` on the test project; the FrameworkReference is lighter.)

## Make `Program` visible
The template uses top-level statements; add to the host's `Program.cs` (or HostingExtensions):
```csharp
public partial class Program { }
```

## Handle template specifics
- The template calls `Log.Logger = new LoggerConfiguration()...CreateBootstrapLogger()` and `Serilog` in a try/catch; this works under the factory but may cause "logger already frozen" errors with multiple factories – use a single shared fixture.
- Template uses `AddDeveloperSigningCredential` / automatic key management that writes to disk; disable with `KeyManagement.Enabled = false` in tests if needed.
- The template's client `m2m.client` with secret `secret` and scope `scope1` (in `Config.cs`) can be reused directly.

## Test
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
        Assert.False(disco.IsError, disco.Error);
        Assert.NotNull(disco.TokenEndpoint);
        Assert.Contains("client_credentials", disco.GrantTypesSupported);
    }

    [Fact]
    public async Task Client_credentials_token_is_issued()
    {
        var disco = await _client.GetDiscoveryDocumentAsync();
        var token = await _client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint,
            ClientId = "m2m.client",
            ClientSecret = "secret",
            Scope = "scope1"
        });
        Assert.False(token.IsError, token.Error);
        Assert.NotEmpty(token.AccessToken!);
    }
}
```
Discovery may complain about the authority/HTTPS mismatch (`http://localhost` vs the configured issuer); if so, set `DiscoveryPolicy { RequireHttps = false, ValidateIssuerName = false }` or pass `Address = "http://localhost"`.
