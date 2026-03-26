# Blazor Server Token Management — Fixing Expired Token Issues

## The Problem

In Blazor Server, the application runs on the server over a persistent SignalR connection called a "circuit." The initial HTTP request that starts the circuit has an `HttpContext`, but once the circuit is established, **`HttpContext` becomes `null`**. This means the default cookie-based token storage (which relies on `HttpContext`) cannot read or refresh tokens after the circuit is up.

This is why your API calls start failing with 401s after a while — the access token expires, and the library can't access the refresh token through `HttpContext` to get a new one.

## The Solution

Use `AddBlazorServerAccessTokenManagement<T>()` with a custom `IUserTokenStore` backed by persistent storage (e.g., a database), and capture tokens during the `OnTokenValidated` OIDC event — the only point where `HttpContext` is available during authentication.

## Implementation

### 1. Program.cs — Registration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContextFactory<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "blazor-app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");
    options.Scope.Add("offline_access");

    // Capture tokens during initial OIDC authentication
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

// Register token management with Blazor Server support
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();

// Register HTTP clients
builder.Services.AddUserAccessTokenHttpClient("api",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com");
    });
```

### 2. Custom IUserTokenStore Implementation

The store must implement `GetTokenAsync`, `StoreTokenAsync`, and `ClearTokenAsync`, backed by persistent storage:

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

### 3. Entity for Token Storage

```csharp
public class StoredUserToken
{
    public string SubjectId { get; set; } = default!;
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
    public DateTimeOffset Expiration { get; set; }
}
```

## Why This Works

1. **`OnTokenValidated`** fires during the initial OIDC authentication HTTP request — the only time `HttpContext` is available. The tokens are persisted to the database immediately.

2. **`AddBlazorServerAccessTokenManagement<ServerSideTokenStore>()`** replaces the default cookie-based `IUserTokenStore` with your database-backed implementation. When the token management library needs to read or refresh tokens during the circuit's lifetime, it reads from the database instead of trying to access `HttpContext`.

3. When the access token expires, the library reads the refresh token from the database, requests a new access token from the authorization server, and stores the updated tokens back — all without needing `HttpContext`.

## Common Mistake

```csharp
// ❌ This will throw NullReferenceException in Blazor Server circuits
var token = await HttpContext.GetUserAccessTokenAsync();

// ✅ Use the IUserTokenStore-backed approach above
```
