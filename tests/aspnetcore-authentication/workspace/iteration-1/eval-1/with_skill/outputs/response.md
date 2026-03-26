# OIDC Authentication Configuration

Here's your complete `Program.cs` configured with OIDC authentication:

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.Name = "myapp";
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code"; // Authorization code flow with PKCE

    // Disable Microsoft's JWT claim type mapping
    options.MapInboundClaims = false;

    // Clear default scopes and add only what we need
    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    // Store tokens in the authentication cookie
    options.SaveTokens = true;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

## Key Points

1. **`MapInboundClaims = false`** prevents renaming `sub` to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.
2. **`Scope.Clear()`** before adding scopes prevents duplicates (OIDC handler adds `openid` and `profile` by default).
3. **`ResponseType = "code"`** uses Authorization Code flow with PKCE (automatic in .NET 7+).
4. **`SaveTokens = true`** stores access/refresh tokens in the cookie for later API calls.
5. **Middleware ordering**: `UseAuthentication()` before `UseAuthorization()`.
