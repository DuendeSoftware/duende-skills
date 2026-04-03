# Blazor Server Token Management

## The Problem

In Blazor Server, the app runs on the server inside a SignalR circuit. After the initial HTTP request that sets up the circuit, `HttpContext` becomes unavailable. This means you can't use the typical ASP.NET Core patterns to access tokens from the authentication properties.

When the access token expires, the app can't refresh it because it has no way to read the existing tokens from the HTTP context.

## Possible Solutions

### Option 1: Store Tokens in a Service

You could create a scoped service that captures the tokens during the initial page load and stores them for later use:

```csharp
public class TokenProvider
{
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
}
```

In your `_Host.cshtml` or initial page:
```csharp
@{
    var accessToken = await HttpContext.GetTokenAsync("access_token");
    var refreshToken = await HttpContext.GetTokenAsync("refresh_token");
}
```

Pass these to the Blazor app through a cascading parameter.

### Option 2: Use a Custom Token Store

Implement a custom storage mechanism that persists tokens to a database, so they're available even when `HttpContext` is null:

```csharp
public class DatabaseTokenStore
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;
    
    public async Task<string?> GetAccessTokenAsync(string userId)
    {
        using var db = await _dbFactory.CreateDbContextAsync();
        var stored = await db.UserTokens.FindAsync(userId);
        return stored?.AccessToken;
    }
    
    public async Task StoreTokensAsync(string userId, string accessToken, string refreshToken)
    {
        using var db = await _dbFactory.CreateDbContextAsync();
        var stored = await db.UserTokens.FindAsync(userId) ?? new UserTokenEntity { UserId = userId };
        stored.AccessToken = accessToken;
        stored.RefreshToken = refreshToken;
        db.UserTokens.Update(stored);
        await db.SaveChangesAsync();
    }
}
```

### Notes

- The core issue is that Blazor Server circuits don't have access to `HttpContext` after initialization.
- You need to capture and persist tokens during the initial HTTP request.
- Consider implementing token refresh logic in your custom store.
- If using Duende.AccessTokenManagement, check if there are Blazor-specific extensions available.
