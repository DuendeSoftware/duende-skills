# User Token Management with OpenID Connect

Here's how to set up cookie + OIDC authentication and have Duende's OpenID Connect access token management attach the user's token to a named `invoices` HTTP client, with refresh token revocation on logout.

## Package

```bash
dotnet add package Duende.AccessTokenManagement.OpenIdConnect
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie(options =>
    {
        // Revoke the refresh token when the user signs out
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

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access"); // needed for refresh tokens

        // Persist tokens so the token management library can use them
        options.SaveTokens = true;

        options.GetClaimsFromUserInfoEndpoint = true;
    });

// Register token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Named client that automatically sends the user's access token
builder.Services.AddUserAccessTokenHttpClient("invoices", configureClient: client =>
{
    client.BaseAddress = new Uri("https://api.example.com/invoices/");
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/invoices", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("invoices");
    var result = await client.GetAsync("list");
    return await result.Content.ReadAsStringAsync();
}).RequireAuthorization();

app.Run();
```

## What each piece does

- **`AddAuthentication` + `AddCookie` + `AddOpenIdConnect`** — sign the user in with the cookie scheme and challenge with OIDC against `https://sts.example.com`.
- **`options.SaveTokens = true`** — stores the access and refresh tokens in the auth session so the library can read and refresh them. Without this the token management can't find the tokens.
- **`offline_access` scope** — asks the identity provider to return a refresh token so tokens can be renewed silently.
- **`AddOpenIdConnectAccessTokenManagement()`** — registers the services that acquire and refresh user tokens.
- **`AddUserAccessTokenHttpClient("invoices", ...)`** — registers a named `HttpClient` whose handler adds the current user's access token as a bearer token on every request and refreshes it when expired.
- **`OnSigningOut` → `RevokeRefreshTokenAsync()`** — calls the revocation endpoint so the refresh token can't be reused after the user logs out.

Then just resolve `factory.CreateClient("invoices")` in your controllers/endpoints and make calls — the token is handled for you.
