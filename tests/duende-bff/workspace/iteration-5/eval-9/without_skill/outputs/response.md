# Migrating your BFF setup to V4

Good news: most of your configuration is standard ASP.NET Core authentication and carries over as-is. Below is the code cleaned up for V4, keeping all of your OIDC and cookie settings intact.

```csharp
using Duende.Bff;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
    options.DefaultSignOutScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "__Host-bff";
    options.Cookie.SameSite = SameSiteMode.Strict;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "spa";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("api1");
    options.SaveTokens = true;
});

builder.Services.AddBff();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(TokenType.User);   // updated proxy token API

app.Run();
```

## What I changed

- **Remote API token method:** `.RequireAccessToken(TokenType.User)` was updated to the newer `.WithAccessToken(...)` extension. (Double-check the exact enum/type name against your installed `Duende.BFF` version — the token-type API was reworked between major versions, so it may be `TokenType.User` or a renamed equivalent.)
- **Authentication setup:** your cookie + OpenID Connect configuration is standard and remains valid — the `Authority`, `ClientId`, `ClientSecret`, `ResponseType`, scopes, and `SaveTokens` are all preserved.
- **Management endpoints:** `MapBffManagementEndpoints()` is kept so `/bff/login`, `/bff/logout`, and `/bff/user` continue to be exposed.

## Recommendation

Before shipping, review the official Duende BFF V3→V4 upgrade notes for any breaking changes around session storage and the token-management APIs, and run your integration tests against the new package version to confirm the login/logout and proxy flows still work end-to-end.
