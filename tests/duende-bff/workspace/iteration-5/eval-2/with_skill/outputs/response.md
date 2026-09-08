# Local API endpoint + remote API proxy with BFF v4

You need two things:

1. A **local** (embedded) endpoint `GET /api/orders` that requires auth and is CSRF-protected.
2. A **remote** proxy from `/api/catalog` to `https://catalog-service.internal/api` that forwards the user's access token.

For the remote proxy you must register the remote-API services with `.AddRemoteApis()` on the BFF builder, and attach the user token with `.WithAccessToken(RequiredTokenType.User)`.

```csharp
using Duende.Bff;
using Duende.Bff.Yarp;   // MapRemoteBffApiEndpoint / WithAccessToken live here

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority    = builder.Configuration["Oidc:Authority"];
        options.ClientId     = builder.Configuration["Oidc:ClientId"];
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
        options.ResponseType = "code";
        options.SaveTokens   = true;
        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    })
    .AddRemoteApis();   // ✅ Required in v4 to enable remote API proxying

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// ✅ Local embedded API — returns order data, requires auth, CSRF-protected
app.MapGet("/api/orders", () => Results.Ok(new[]
    {
        new { id = 1, total = 42.00m },
        new { id = 2, total = 17.50m }
    }))
    .RequireAuthorization()   // enforce authenticated user
    .AsBffApiEndpoint();      // enforce X-CSRF anti-forgery header

// ✅ Remote proxy — forwards the user's access token to the catalog service
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .WithAccessToken(RequiredTokenType.User);

app.Run();
```

## Why it's built this way

- **`.AsBffApiEndpoint()`** on the local endpoint enforces the `X-CSRF: 1` anti-forgery header. Without it, the endpoint is CSRF-vulnerable — any BFF API endpoint reachable from the browser needs it.
- **`.RequireAuthorization()`** ensures only an authenticated session can hit `/api/orders`.
- **`.AddRemoteApis()`** registers the services `MapRemoteBffApiEndpoint` depends on. In v4 this is a required opt-in; forgetting it means the remote mapping won't resolve.
- **`.WithAccessToken(RequiredTokenType.User)`** tells BFF to fetch the current user's access token (refreshing it automatically via AccessTokenManagement) and attach it as a Bearer token when forwarding to `https://catalog-service.internal/api`. Because it's `User`, an unauthenticated caller is challenged.
- The path `/api/catalog` and **all sub-paths** are proxied to the target URI, so `/api/catalog/items/5` → `https://catalog-service.internal/api/items/5`.

From the SPA, remember every call needs the anti-forgery header:

```javascript
await fetch('/api/orders',  { headers: { 'X-CSRF': '1' } });
await fetch('/api/catalog', { headers: { 'X-CSRF': '1' } });
```
