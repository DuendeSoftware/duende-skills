# Blazor Server 401s: Why HttpContext Doesn't Work in Circuits

## What's going on

A Blazor Server circuit is a long-lived SignalR connection. Only the **initial** HTTP request that establishes the circuit has an `HttpContext`; every subsequent interaction happens over the SignalR channel with **no `HttpContext`**. The default `IUserTokenStore` reads tokens from the authentication cookie via `HttpContext`, so once the circuit is established it finds `null` (or stale) data. It can't read or refresh the user's access token, and after the token expires your API calls start returning 401.

So this fails at runtime:

```csharp
// ❌ HttpContext is null after circuit establishment — throws / returns stale data
var token = await HttpContext.GetUserAccessTokenAsync();
```

## The fix: circuit-safe token management with a persistent store

Use `AddBlazorServerAccessTokenManagement<T>()` with a **custom `IUserTokenStore`** backed by persistent storage (e.g. a database), so tokens survive across circuit reconnections and are available without `HttpContext`. Capture the tokens during the initial OIDC flow in `OnTokenValidated` — the one place `HttpContext` is available — and persist them to that store.

### 1. Register it

```csharp
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();
```

### 2. Implement `IUserTokenStore`

```csharp
public class ServerSideTokenStore : IUserTokenStore
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    public ServerSideTokenStore(IDbContextFactory<AppDbContext> dbFactory)
        => _dbFactory = dbFactory;

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

### 3. Capture tokens in `OnTokenValidated`

The initial OIDC authentication is the only point where `HttpContext` exists, so persist the tokens there:

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("oidc", options =>
    {
        // ... other OIDC config ...
        options.SaveTokens = true;
        options.Scope.Add("offline_access");

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
```

## Summary

- **Root cause:** `HttpContext` is unavailable in Blazor Server circuits after the initial request, so the cookie-based token store can't serve/refresh tokens → 401s once the token expires.
- **Fix:** `AddBlazorServerAccessTokenManagement<ServerSideTokenStore>()` with a database-backed `IUserTokenStore` (`GetTokenAsync` / `StoreTokenAsync` / `ClearTokenAsync`), and capture tokens in `OnTokenValidated`. From then on, the token management services read/refresh tokens from your store, no `HttpContext` required.
