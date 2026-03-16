# Configuring OIDC Authentication for Your Web App

Here's the updated `Program.cs` with full OIDC authentication configured for your web app:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.Name = "webapp";
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = true;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code"; // Authorization code flow (PKCE is automatic in .NET 7+)

    // Clear default scopes to avoid duplicates, then add the ones we need
    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    // Save tokens in the authentication cookie for later API calls
    options.SaveTokens = true;

    // CRITICAL: Disable Microsoft's JWT claim type mapping
    // Without this, 'sub' gets mapped to the long XML URI
    // 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'
    options.MapInboundClaims = false;

    options.GetClaimsFromUserInfoEndpoint = true;

    options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

// Authentication MUST come before Authorization in the middleware pipeline
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

## Key Settings Explained

| Setting | Why |
|---------|-----|
| `DefaultScheme = "Cookies"` | Cookie handler reads existing sessions for every request |
| `DefaultChallengeScheme = "oidc"` | Unauthenticated users redirect to IdentityServer |
| `MapInboundClaims = false` | Prevents silent renaming of `sub`, `name`, `role` to XML URIs |
| `Scope.Clear()` | The OIDC handler adds `openid` and `profile` by default — clearing first prevents duplicates |
| `SaveTokens = true` | Stores access/refresh/ID tokens in the cookie for later API calls |
| `ResponseType = "code"` | Authorization code flow with PKCE (automatic in .NET 7+) |
| `UseAuthentication()` before `UseAuthorization()` | Authentication must establish identity before authorization can check it |
