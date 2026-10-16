# User token management with cookie + OIDC

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", o =>
{
    o.Cookie.Name = "__Host-webapp";
    o.Cookie.SameSite = SameSiteMode.Lax;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = builder.Configuration["IdentityServer:ClientId"];
    options.ClientSecret = builder.Configuration["IdentityServer:ClientSecret"];
    options.ResponseType = "code";
    options.UsePkce = true;
    options.SaveTokens = true;          // required: tokens live in the cookie
    options.GetClaimsFromUserInfoEndpoint = true;
    options.MapInboundClaims = false;

    options.Scope.Clear();
    foreach (var s in "openid profile email invoice offline_access".Split(' '))
        options.Scope.Add(s);
});

builder.Services.AddAuthorization();
builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddUserAccessTokenHttpClient("invoices", configureClient: c =>
{
    c.BaseAddress = new Uri("https://api.example.com/invoices/");
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.MapGet("/call-api", async (IHttpClientFactory f, CancellationToken ct) =>
{
    var http = f.CreateClient("invoices");
    return Results.Ok(await http.GetStringAsync("", ct));
}).RequireAuthorization();

app.MapPost("/logout", async (HttpContext ctx) =>
{
    // revoke refresh token at the STS, then sign out
    await ctx.RevokeRefreshTokenAsync();
    await ctx.SignOutAsync("cookie");
    await ctx.SignOutAsync("oidc", new AuthenticationProperties { RedirectUri = "/" });
}).RequireAuthorization();

app.Run();
```

- `offline_access` gives a refresh token; `SaveTokens = true` stores it in the cookie so the library can refresh it.
- `AddUserAccessTokenHttpClient` adds a handler that gets the current user's token (refreshing when needed).
- Logout is a POST (avoid GET for CSRF reasons) and revokes the refresh token before clearing the cookie.
