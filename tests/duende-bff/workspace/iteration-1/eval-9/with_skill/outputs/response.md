# Migrating from BFF v3 to v4

Here's the migrated code:

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "spa";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("api1");
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
    })
    .AddRemoteApis();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User);

app.Run();
```

## What Changed

| V3 | V4 |
|---|---|
| `AddAuthentication().AddCookie().AddOpenIdConnect()` | `AddBff().ConfigureOpenIdConnect().ConfigureCookies()` |
| `MapBffManagementEndpoints()` | Removed — auto-registered by `AddBff()` |
| `.RequireAccessToken(TokenType.User)` | `.WithAccessToken(RequiredTokenType.User)` |
| `AddBff()` alone | `AddBff().AddRemoteApis()` for remote endpoints |

## Key Migration Points

- **`ConfigureOpenIdConnect`** replaces the manual auth handler setup. All original settings (Authority, ClientId, etc.) are preserved.
- **`ConfigureCookies`** replaces the manual `AddCookie` call. Cookie settings are preserved.
- **`MapBffManagementEndpoints()`** is removed — v4 registers management endpoints automatically.
- **`AddRemoteApis()`** must be added since v4 requires explicit opt-in for remote API support.
- **`.WithAccessToken(RequiredTokenType.User)`** replaces `.RequireAccessToken(TokenType.User)`.
