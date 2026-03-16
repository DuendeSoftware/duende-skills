# Migrating BFF V3 to V4

Here's your code migrated to BFF V4 conventions. The key changes are:

1. **Replace manual `AddAuthentication`/`AddCookie`/`AddOpenIdConnect`** with the V4 fluent API: `AddBff().ConfigureOpenIdConnect().ConfigureCookies()`
2. **Remove `MapBffManagementEndpoints()`** — management endpoints are auto-registered in V4
3. **Update `.RequireAccessToken(TokenType.User)`** to `.WithAccessToken(RequiredTokenType.User)`
4. **Add `.AddRemoteApis()`** — required in V4 for remote API endpoint support

## Migrated Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// V4: AddBff() with fluent OIDC and cookie configuration
// replaces manual AddAuthentication + AddCookie + AddOpenIdConnect
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "spa";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("api1");
        options.SaveTokens = true;
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
    })
    .AddRemoteApis(); // V4: required for MapRemoteBffApiEndpoint

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// V4: MapBffManagementEndpoints() is removed — endpoints are auto-registered

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User); // V4: replaces .RequireAccessToken(TokenType.User)

app.Run();
```

## Summary of Changes

| V3 Code | V4 Replacement |
|---|---|
| `AddAuthentication().AddCookie().AddOpenIdConnect()` | `AddBff().ConfigureOpenIdConnect().ConfigureCookies()` |
| `MapBffManagementEndpoints()` | Removed — auto-registered by `AddBff()` |
| `.RequireAccessToken(TokenType.User)` | `.WithAccessToken(RequiredTokenType.User)` |
| `AddBff()` alone | `AddBff().AddRemoteApis()` for remote API support |

All original OIDC settings (Authority, ClientId, ClientSecret, ResponseType, scopes, SaveTokens) and cookie settings (Name, SameSite) are preserved in the V4 configuration.
