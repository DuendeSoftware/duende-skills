# User Token Management for ASP.NET Core Web App

Here's the complete setup for an ASP.NET Core web app with cookie + OIDC authentication, user token management via Duende.AccessTokenManagement.OpenIdConnect, and a named HTTP client that automatically attaches the user's access token.

## Updated `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// Configure authentication: cookie + OIDC
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "web";
    // Revoke refresh token at sign-out
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync();
    };
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "webapp";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.ResponseMode = "query";

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");
    options.Scope.Add("invoice");
    options.Scope.Add("offline_access"); // Required for refresh tokens

    options.GetClaimsFromUserInfoEndpoint = true;
    options.MapInboundClaims = false;

    // REQUIRED — persists access and refresh tokens into the auth session
    options.SaveTokens = true;
});

// Register user token management services
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register a named HTTP client that automatically attaches the user's access token
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.MapGet("/call-api", async (IHttpClientFactory httpClientFactory, CancellationToken ct) =>
{
    // Token attached automatically; refreshed silently if expired
    var client = httpClientFactory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    var content = await response.Content.ReadAsStringAsync(ct);
    return Results.Ok(content);
}).RequireAuthorization();

app.Run();
```

## Key Points

1. **`SaveTokens = true`** is mandatory on the OpenIdConnect handler. Without it, the library cannot read or refresh the user's access token and will throw `InvalidOperationException` at runtime.
2. **`offline_access`** scope is included to enable refresh tokens — without this, the access token will expire and the user must re-authenticate.
3. **`RevokeRefreshTokenAsync()`** is wired in `OnSigningOut` to revoke the refresh token at the authorization server when the user signs out. This prevents reuse of the token after logout.
4. **`AddOpenIdConnectAccessTokenManagement()`** registers all the user token management services, including token refresh and caching.
5. **`AddUserAccessTokenHttpClient("invoices", ...)`** registers a named HTTP client that automatically acquires and attaches the current user's access token. If the token is expired, it's silently refreshed using the refresh token.

## Packages Required

```xml
<PackageReference Include="Duende.AccessTokenManagement.OpenIdConnect" Version="4.0.0" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.OpenIdConnect" Version="9.0.0" />
```
