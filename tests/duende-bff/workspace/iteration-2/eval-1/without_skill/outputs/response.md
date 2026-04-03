Here's how to set up your ASP.NET Core app with Duende BFF to secure a React SPA:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "OpenIdConnect";
    options.DefaultSignOutScheme = "OpenIdConnect";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;
})
.AddOpenIdConnect("OpenIdConnect", options =>
{
    options.Authority = "https://idp.example.com";
    options.ClientId = "spa-bff-client";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;

    options.Scope.Clear();
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

app.MapGet("/", () => "Hello World");

app.Run();
```

This sets up:
- Cookie authentication for maintaining the session
- OpenID Connect for authenticating with your IDP
- BFF middleware for securing your SPA's API calls
- The `offline_access` scope enables refresh tokens so your tokens can be automatically renewed

Make sure you have the `Duende.BFF` NuGet package installed.
