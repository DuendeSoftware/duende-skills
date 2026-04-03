Here's how to migrate your v3 BFF setup to v4:

```csharp
// Program.cs — Migrated to BFF v4
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
    .AddRemoteApis(); // Required in v4 for remote API endpoints

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// MapBffManagementEndpoints() removed — v4 auto-registers management endpoints

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User); // v4 syntax replaces .RequireAccessToken(TokenType.User)

app.Run();
```

Changes made:

1. **Replaced manual auth setup with fluent API** — `AddAuthentication().AddCookie().AddOpenIdConnect()` is replaced by `AddBff().ConfigureOpenIdConnect().ConfigureCookies()`. The v4 API auto-configures scheme names and recommended defaults.

2. **Removed `MapBffManagementEndpoints()`** — In v4, management endpoints (`/bff/login`, `/bff/logout`, `/bff/user`, `/bff/backchannel-logout`) are registered automatically by `AddBff()`.

3. **Updated token type syntax** — `.RequireAccessToken(TokenType.User)` is replaced by `.WithAccessToken(RequiredTokenType.User)`.

4. **Added `.AddRemoteApis()`** — V4 requires this on the BFF builder for `MapRemoteBffApiEndpoint` to work.

5. **Preserved all OIDC settings** — Authority, ClientId, ClientSecret, ResponseType, scopes, and cookie settings are all carried over.
