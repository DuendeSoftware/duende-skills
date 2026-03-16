# Hosting DCR in a Separate Application

When hosting DCR in a separate application from your main IdentityServer, you use `AddIdentityServerConfiguration` with the `IdentityServerBaseUrl` option pointing to your main IdentityServer instance. The separate host does **not** run IdentityServer itself — it only hosts the DCR endpoint.

## Separate DCR Host — Program.cs

```csharp
using Duende.IdentityServer.Configuration;

var builder = WebApplication.CreateBuilder(args);

// Add DCR configuration pointing to the main IdentityServer
builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
});

// Set up JWT bearer authentication against the main IdentityServer
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Map the DCR endpoint with authorization
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## Key Points

1. **`AddIdentityServerConfiguration(options => { options.IdentityServerBaseUrl = "https://identity.example.com"; })`** — This tells the DCR host where the main IdentityServer lives. The DCR host uses this to fetch discovery information and validate tokens.

2. **JWT Bearer Authentication** — The DCR host authenticates callers using JWT bearer tokens issued by the main IdentityServer. The `Authority` is set to `https://identity.example.com`.

3. **`MapDynamicClientRegistration().RequireAuthorization("dcr")`** — Maps the DCR endpoint and secures it with the authorization policy.

4. **No `AddIdentityServer()` call** — This is a separate host, not an IdentityServer instance. You do **not** call `AddIdentityServer()`. Only the DCR configuration services are registered.

5. **Shared `IClientConfigurationStore`** — The DCR host must write to the same database that the main IdentityServer reads from. The `IClientConfigurationStore` must be backed by the same database (e.g., using the Entity Framework `AddClientConfigurationStore()`) so that clients registered through DCR are visible to IdentityServer.

## Separate DCR Host .csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Duende.IdentityServer.Configuration" Version="7.1.0" />
    <PackageReference Include="Duende.IdentityServer.Configuration.EntityFramework" Version="7.1.0" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="9.0.0" />
  </ItemGroup>
</Project>
```
