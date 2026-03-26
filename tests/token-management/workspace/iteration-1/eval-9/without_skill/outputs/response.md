# Blazor Server Token Expiration Issue

## What's Happening

In Blazor Server, your app runs over a SignalR connection (called a "circuit"). The initial HTTP request has an `HttpContext`, but after the WebSocket connection is established, `HttpContext` is no longer available. This is a well-known Blazor Server limitation.

The default token management relies on the authentication cookie (via `HttpContext`) to read and refresh tokens. Since `HttpContext` is null in the circuit, the library can't access or refresh your tokens, leading to 401 errors when the access token expires.

## Fix

You need to store tokens in a persistent store that doesn't depend on `HttpContext`. Here's the approach:

### 1. Create a Token Store

Store tokens in a database or cache that can be accessed without `HttpContext`:

```csharp
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

### 2. Register the Custom Store

```csharp
// Register custom token store
builder.Services.AddSingleton<IUserTokenStore, ServerSideTokenStore>();

builder.Services.AddOpenIdConnectAccessTokenManagement();
```

### 3. Capture Tokens During Authentication

You need to save tokens when the user first authenticates, since that's the only time you have access to them via HTTP:

```csharp
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
```

This way, tokens are persisted during the initial OIDC flow and can be accessed later from Blazor components without needing `HttpContext`.
