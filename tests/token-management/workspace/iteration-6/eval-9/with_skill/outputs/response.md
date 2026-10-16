# Blazor Server and expiring tokens

## What's going on
A Blazor Server circuit is a long-lived SignalR connection. `HttpContext` exists only for the initial HTTP request; afterward it's `null` or stale. The default user token store keeps tokens in the authentication cookie, which requires `HttpContext` to read and to write refreshed tokens. In a circuit, the library can't update the cookie, so the access token saved at login simply expires and API calls get 401. Calling `HttpContext.GetUserAccessTokenAsync()` in components fails with null reference.

## Fix
Use a server-side `IUserTokenStore` backed by persistent storage and register it with `AddBlazorServerAccessTokenManagement<T>()`. Capture the tokens during the initial OIDC flow, the only point where `HttpContext` is available.

```csharp
builder.Services.AddAuthentication(o =>
    {
        o.DefaultScheme = "cookie";
        o.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = builder.Configuration["IdentityServer:ClientSecret"];
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("offline_access");

        options.Events.OnTokenValidated = async context =>
        {
            var store = context.HttpContext.RequestServices.GetRequiredService<IUserTokenStore>();
            var token = new UserToken
            {
                AccessToken = context.TokenEndpointResponse?.AccessToken,
                RefreshToken = context.TokenEndpointResponse?.RefreshToken,
                Expiration = DateTimeOffset.UtcNow.AddSeconds(
                    int.Parse(context.TokenEndpointResponse?.ExpiresIn ?? "3600"))
            };
            await store.StoreTokenAsync(context.Principal!, token);
        };
    });

builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();

builder.Services.AddUserAccessTokenHttpClient("invoices",
    configureClient: c => c.BaseAddress = new Uri("https://api.example.com/invoices/"));
```

```csharp
public class ServerSideTokenStore(IDbContextFactory<AppDbContext> dbFactory) : IUserTokenStore
{
    public async Task<UserToken> GetTokenAsync(ClaimsPrincipal user, UserTokenRequestParameters? parameters = null)
    {
        var sub = user.FindFirst("sub")?.Value;
        await using var db = await dbFactory.CreateDbContextAsync();
        var s = await db.UserTokens.FindAsync(sub);
        return new UserToken
        {
            AccessToken = s?.AccessToken,
            RefreshToken = s?.RefreshToken,
            Expiration = s?.Expiration ?? DateTimeOffset.MinValue
        };
    }

    public async Task StoreTokenAsync(ClaimsPrincipal user, UserToken token, UserTokenRequestParameters? parameters = null)
    {
        var sub = user.FindFirst("sub")?.Value;
        await using var db = await dbFactory.CreateDbContextAsync();
        var s = await db.UserTokens.FindAsync(sub);
        if (s == null) { s = new StoredUserToken { SubjectId = sub! }; db.UserTokens.Add(s); }
        s.AccessToken = token.AccessToken;
        s.RefreshToken = token.RefreshToken;
        s.Expiration = token.Expiration;
        await db.SaveChangesAsync();
    }

    public async Task ClearTokenAsync(ClaimsPrincipal user, UserTokenRequestParameters? parameters = null)
    {
        var sub = user.FindFirst("sub")?.Value;
        await using var db = await dbFactory.CreateDbContextAsync();
        var s = await db.UserTokens.FindAsync(sub);
        if (s != null) { db.UserTokens.Remove(s); await db.SaveChangesAsync(); }
    }
}
```

In components, inject `IHttpClientFactory` and use `CreateClient("invoices")`; the handler gets/refreshes the token from your store. Never touch `HttpContext` there, and don't keep tokens in component fields.

Checklist: `SaveTokens = true`, `offline_access`, persistent store (survives circuit reconnects), tokens captured in `OnTokenValidated`, and `RevokeRefreshTokenAsync()` on sign-out.
