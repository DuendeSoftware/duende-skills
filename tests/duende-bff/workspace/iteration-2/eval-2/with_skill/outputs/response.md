Here's how to set up both a local API endpoint and a remote API proxy with BFF v4:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
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
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    })
    .AddRemoteApis(); // Required in v4 for MapRemoteBffApiEndpoint

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Local API endpoint — served by this application
app.MapGet("/api/orders", (HttpContext ctx) =>
{
    var orders = new[]
    {
        new { Id = 1, Name = "Order #1", Total = 99.99 },
        new { Id = 2, Name = "Order #2", Total = 149.50 }
    };
    return Results.Ok(orders);
})
.RequireAuthorization()     // Requires authenticated user
.AsBffApiEndpoint();        // Enforces X-CSRF header for CSRF protection

// Remote API endpoint — proxied to catalog service
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
    .WithAccessToken(RequiredTokenType.User);   // Forwards user's access token

app.Run();
```

Key points:

1. **Local endpoint uses `.AsBffApiEndpoint()`** — This enforces the `X-CSRF: 1` header requirement, protecting against CSRF attacks. Without it, the endpoint would be vulnerable.

2. **Local endpoint uses `.RequireAuthorization()`** — Ensures only authenticated users can access `/api/orders`.

3. **`.AddRemoteApis()`** is called on the BFF builder — This is required in v4 for `MapRemoteBffApiEndpoint` to work. It registers the YARP-based proxying infrastructure.

4. **`MapRemoteBffApiEndpoint`** maps `/api/catalog` (and all sub-paths) to the remote catalog service. BFF handles the token exchange automatically — the browser sends only the session cookie, and BFF attaches the user's access token before forwarding to the upstream API.

5. **`.WithAccessToken(RequiredTokenType.User)`** — Attaches the logged-in user's access token to the proxied request. If the user is not authenticated, BFF will return a 401 (not a redirect) to the SPA.
