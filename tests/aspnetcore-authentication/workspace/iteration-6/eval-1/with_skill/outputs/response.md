```csharp
var builder = WebApplication.CreateBuilder(args);

var auth = builder.Configuration.GetSection("Authentication");

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = auth["Authority"];          // https://identity.example.com
    options.ClientId = auth["ClientId"];            // web.app
    options.ClientSecret = auth["ClientSecret"];
    options.ResponseType = "code";                  // authorization code + PKCE

    options.Scope.Clear();                          // drop defaults first
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    options.SaveTokens = true;
    options.GetClaimsFromUserInfoEndpoint = true;

    // Don't remap sub/name/role to XML URIs
    options.MapInboundClaims = false;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();   // must precede authorization
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

Add `using Microsoft.IdentityModel.Tokens;` for `TokenValidationParameters`.

- `MapInboundClaims = false` keeps `sub` as `sub` rather than `.../nameidentifier`.
- `Scope.Clear()` first avoids duplicating the default scopes.
- `UseAuthentication()` goes before `UseAuthorization()`.
- Move the client secret to user-secrets/a vault outside development.
