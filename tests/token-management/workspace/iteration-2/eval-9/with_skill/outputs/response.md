# Blazor Server Token Management

## The Problem

In Blazor Server, circuits outlive the initial HTTP request. Once a SignalR circuit is established, `HttpContext` is `null` for all subsequent interactions. The default cookie-based `IUserTokenStore` in Duende.AccessTokenManagement depends on `HttpContext`, so it's unusable after circuit setup. This is why your API calls start failing with 401s — the tokens expire, but the library can't refresh them because it can't read the tokens from `HttpContext`.

## The Fix

Use `AddBlazorServerAccessTokenManagement<T>()` with a custom `IUserTokenStore` backed by persistent storage (e.g., a database), and capture the tokens during the `OnTokenValidated` OIDC event — the only point where `HttpContext` is still available.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

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
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;

    // Capture tokens during initial OIDC flow — HttpContext is available here
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

// Register user token management with Blazor Server support
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();

// Register HTTP clients that use the user's token
builder.Services.AddUserAccessTokenHttpClient("api",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/");
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## Custom `IUserTokenStore` Implementation

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

## Key Points

1. **`HttpContext` is not available in Blazor Server circuits** after the initial HTTP request. The circuit is a long-lived SignalR connection — all subsequent interactions happen without an HTTP context.
2. **`AddBlazorServerAccessTokenManagement<ServerSideTokenStore>()`** registers a custom `IUserTokenStore` that uses persistent storage instead of the cookie-based default.
3. The custom `IUserTokenStore` implements `GetTokenAsync`, `StoreTokenAsync`, and `ClearTokenAsync` methods backed by a database.
4. **Tokens are captured during `OnTokenValidated`** — this is the only point during the OIDC flow where `HttpContext` is available and tokens can be persisted to the custom store.
