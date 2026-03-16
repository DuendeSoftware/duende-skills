# Blazor Server Token Management

## The Problem

In Blazor Server, once a SignalR circuit is established, `HttpContext` becomes `null`. The initial HTTP request that establishes the circuit has an `HttpContext`, but all subsequent interactions happen over the SignalR channel without one. The default cookie-based `IUserTokenStore` relies on `HttpContext` to read and write tokens, so after the circuit is established it cannot access or refresh tokens — causing 401 errors when the access token expires.

## The Solution

Duende.AccessTokenManagement provides `AddBlazorServerAccessTokenManagement<T>()` specifically for this scenario. You must implement a custom `IUserTokenStore` backed by persistent storage (database, etc.) so tokens survive across circuit reconnections, and capture tokens during the initial OIDC authentication flow via the `OnTokenValidated` event.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// ── Authentication: cookie + OIDC ──
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
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
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");

        options.SaveTokens = true;

        // ✅ Capture tokens during initial OIDC flow — the only point where HttpContext is available
        options.Events.OnTokenValidated = async context =>
        {
            var store = context.HttpContext.RequestServices
                .GetRequiredService<IUserTokenStore>();
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

// ── Token management with Blazor Server support ──
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();

// ── Register EF Core for token storage ──
builder.Services.AddDbContextFactory<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
```

## Custom `IUserTokenStore` Implementation

```csharp
using System.Security.Claims;
using Duende.AccessTokenManagement.OpenIdConnect;

public class ServerSideTokenStore : IUserTokenStore
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    public ServerSideTokenStore(IDbContextFactory<AppDbContext> dbFactory)
    {
        _dbFactory = dbFactory;
    }

    public async Task<UserToken> GetTokenAsync(
        ClaimsPrincipal user,
        UserTokenRequestParameters? parameters = null)
    {
        var sub = user.FindFirst("sub")?.Value;
        using var db = await _dbFactory.CreateDbContextAsync();
        var stored = await db.UserTokens.FindAsync(sub);
        return new UserToken
        {
            AccessToken = stored?.AccessToken,
            RefreshToken = stored?.RefreshToken,
            Expiration = stored?.Expiration ?? DateTimeOffset.MinValue
        };
    }

    public async Task StoreTokenAsync(
        ClaimsPrincipal user,
        UserToken token,
        UserTokenRequestParameters? parameters = null)
    {
        var sub = user.FindFirst("sub")?.Value;
        using var db = await _dbFactory.CreateDbContextAsync();
        var stored = await db.UserTokens.FindAsync(sub);
        if (stored == null)
        {
            stored = new StoredUserToken { SubjectId = sub! };
            db.UserTokens.Add(stored);
        }
        stored.AccessToken = token.AccessToken;
        stored.RefreshToken = token.RefreshToken;
        stored.Expiration = token.Expiration;
        await db.SaveChangesAsync();
    }

    public async Task ClearTokenAsync(
        ClaimsPrincipal user,
        UserTokenRequestParameters? parameters = null)
    {
        var sub = user.FindFirst("sub")?.Value;
        using var db = await _dbFactory.CreateDbContextAsync();
        var stored = await db.UserTokens.FindAsync(sub);
        if (stored != null)
        {
            db.UserTokens.Remove(stored);
            await db.SaveChangesAsync();
        }
    }
}
```

## Why This Is Needed

A Blazor Server circuit is a long-lived SignalR connection. The initial HTTP request that establishes the circuit has an `HttpContext`, but all subsequent interactions happen over the SignalR channel without one. Any code that reads `IHttpContextAccessor.HttpContext` or the authentication cookie store after circuit setup will find `null` or stale data.

By using `AddBlazorServerAccessTokenManagement<ServerSideTokenStore>()`:
1. Tokens are captured during `OnTokenValidated` (the only point with `HttpContext`)
2. Stored in a persistent backend (database) via the custom `IUserTokenStore`
3. Read from that store during the circuit lifetime — no dependency on `HttpContext`
4. Refreshed automatically when they expire (the library calls `StoreTokenAsync` with the new token)
