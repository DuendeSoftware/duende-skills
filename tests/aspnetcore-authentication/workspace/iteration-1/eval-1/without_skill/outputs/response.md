# Configuring OIDC Authentication

Here's how to set up OpenID Connect authentication for your web app:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";

    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    options.SaveTokens = true;

    options.GetClaimsFromUserInfoEndpoint = true;
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

## What This Does

1. **Cookie Authentication**: The `DefaultScheme` is set to `Cookies` which handles session management
2. **OIDC Challenge**: When the user isn't authenticated, they're redirected to IdentityServer
3. **Authorization Code Flow**: `ResponseType = "code"` uses the secure authorization code flow
4. **Scopes**: Requesting `openid`, `profile`, and `api1` scopes
5. **Save Tokens**: Tokens are saved in the cookie so you can use them to call APIs later

The middleware ordering is important — `UseAuthentication()` must come before `UseAuthorization()` so the user's identity is established before access checks happen.
