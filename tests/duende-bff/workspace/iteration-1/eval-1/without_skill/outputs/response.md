# Setting Up BFF with OpenID Connect

Here's how to set up a BFF (Backend for Frontend) pattern for a React SPA:

```csharp
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
    options.Authority = "https://idp.example.com";
    options.ClientId = "spa-bff-client";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;

    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("offline_access");
});

builder.Services.AddBff();
builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();
app.MapFallbackToFile("index.html");

app.Run();
```

This sets up cookie-based authentication with OIDC and the BFF middleware for CSRF protection.
