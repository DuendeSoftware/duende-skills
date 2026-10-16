# Blazor Server and 401s

**What's going on:** In Blazor Server, the app runs in a SignalR circuit, not a normal request. `HttpContext` is only valid during the initial HTTP request; afterward it is null or stale, so the cookie-based token store can't be read or updated (cookies can't be written over a WebSocket). The access token saved at login expires (usually in ~1 hour), and refresh can't persist the new token to the cookie, so API calls get 401.

**Fix:** keep tokens in a server-side store rather than the cookie, and use a token management that doesn't depend on `HttpContext`.

```csharp
builder.Services.AddAuthentication(o => { o.DefaultScheme = "cookie"; o.DefaultChallengeScheme = "oidc"; })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", o =>
    {
        o.Authority = "https://sts.example.com";
        o.ClientId = "webapp";
        o.ClientSecret = "secret";
        o.ResponseType = "code";
        o.SaveTokens = true;
        o.Scope.Add("offline_access");
    });

builder.Services.AddOpenIdConnectAccessTokenManagement();

// server-side token store (singleton), e.g. in-memory or backed by a DB/distributed cache
builder.Services.AddSingleton<IUserTokenStore, ServerSideTokenStore>();

builder.Services.AddUserAccessTokenHttpClient("invoices",
    configureClient: c => c.BaseAddress = new Uri("https://api.example.com/invoices/"));
```

Use the `IHttpClientFactory` client in components; never read `HttpContext` there. Also avoid capturing tokens in component state: let the handler fetch them. Capture the token during `OnTokenValidated`/ cookie `OnSigningIn` into the store keyed by user `sub`/session, and refresh via the store. Duende's `Duende.AccessTokenManagement.OpenIdConnect` ships a `ServerSideTokenStore` sample/ approach for this.
