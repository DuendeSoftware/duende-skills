---
name: accesstokenmanagement-usage
description: "Using Duende.AccessTokenManagement for automatic token lifecycle management: user token management with OIDC, client credentials flows, HTTP client factory integration, token caching, DPoP, Blazor Server support, and extensibility."
invocable: false
---

# Access Token Management

## When to Use This Skill

- Setting up automatic user access token management in web applications using OIDC
- Configuring client credentials token management for service-to-service communication
- Integrating token management with `IHttpClientFactory` (named and typed clients)
- Understanding token caching strategies (V4 HybridCache vs V3 IDistributedCache)
- Configuring DPoP proof tokens for token requests and API calls
- Implementing token management in Blazor Server applications
- Using client assertions (`IClientAssertionService`) instead of shared secrets
- Customizing token requests with `ITokenRequestCustomizer` for multi-tenant scenarios
- Building worker services / background services that call protected APIs

## Core Concepts

Duende.AccessTokenManagement automates the lifecycle of access tokens: acquiring, caching, refreshing, and attaching them to outgoing HTTP requests. It provides two independent subsystems:

| Subsystem                         | Flow                         | Token Source                        | Typical Consumer                       |
| --------------------------------- | ---------------------------- | ----------------------------------- | -------------------------------------- |
| **User token management**         | Authorization Code + Refresh | OIDC session (user-specific tokens) | Web apps, Blazor Server                |
| **Client credentials management** | Client Credentials           | Token endpoint (app-level tokens)   | APIs, worker services, background jobs |

Both subsystems integrate with `IHttpClientFactory` to automatically attach tokens to outgoing HTTP requests.

## User Token Management

### Setup

```bash
dotnet add package Duende.AccessTokenManagement.OpenIdConnect
```

```csharp
// Program.cs
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web_app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("api1");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
    options.GetClaimsFromUserInfoEndpoint = true;
});

builder.Services.AddOpenIdConnectAccessTokenManagement();
```

### Critical: SaveTokens and offline_access

```csharp
// ❌ WRONG: Missing SaveTokens — tokens not stored in session
.AddOpenIdConnect("oidc", options =>
{
    options.SaveTokens = false; // tokens are discarded
});

// ❌ WRONG: Missing offline_access — no refresh token issued
options.Scope.Add("api1");
// Missing: options.Scope.Add("offline_access");

// ✅ CORRECT: Both SaveTokens and offline_access required
.AddOpenIdConnect("oidc", options =>
{
    options.SaveTokens = true;
    options.Scope.Add("api1");
    options.Scope.Add("offline_access");
});
```

### Using User Tokens with HttpClient

**Named HTTP client:**

```csharp
// Program.cs
builder.Services.AddUserAccessTokenHttpClient("api-client",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com");
    });

// In a controller or handler
public class DataController : Controller
{
    private readonly IHttpClientFactory _factory;

    public DataController(IHttpClientFactory factory) => _factory = factory;

    public async Task<IActionResult> GetData()
    {
        var client = _factory.CreateClient("api-client");
        var response = await client.GetAsync("/data");
        return Ok(await response.Content.ReadAsStringAsync());
    }
}
```

**Typed HTTP client:**

```csharp
// Program.cs
builder.Services.AddHttpClient<ApiClient>(client =>
{
    client.BaseAddress = new Uri("https://api.example.com");
})
.AddUserAccessTokenHandler();

// ApiClient.cs
public class ApiClient
{
    private readonly HttpClient _client;

    public ApiClient(HttpClient client) => _client = client;

    public async Task<string> GetDataAsync()
    {
        var response = await _client.GetAsync("/data");
        return await response.Content.ReadAsStringAsync();
    }
}
```

### Accessing Tokens Directly

```csharp
// In a controller or handler with HttpContext
var token = await HttpContext.GetUserAccessTokenAsync();
// token.AccessToken — the current (or refreshed) access token
// token.Expiration — when the token expires
```

### V4 vs V3 Differences

| Feature           | V4                                    | V3                            |
| ----------------- | ------------------------------------- | ----------------------------- |
| Service interface | `IUserTokenManager`                   | `IUserTokenManagementService` |
| Token caching     | `HybridCache`                         | `IDistributedCache`           |
| Client name types | `ClientCredentialsClientName.Parse()` | Plain strings                 |

## Client Credentials Token Management

### Setup

```bash
dotnet add package Duende.AccessTokenManagement
```

```csharp
// Program.cs (v4 — strongly typed wrappers)
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("api-client"), client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("service_app");
        client.ClientSecret = ClientSecret.Parse("secret");
        client.Scope = Scope.Parse("api1");
    });

// v3 — plain strings (no Parse wrappers, string-based AddClient overload)
// builder.Services.AddClientCredentialsTokenManagement()
//     .AddClient("api-client", client =>
//     {
//         client.TokenEndpoint = "https://identity.example.com/connect/token";
//         client.ClientId = "service_app";
//         client.ClientSecret = "secret";
//         client.Scope = "api1";
//     });
```

### Using Client Credentials Tokens with HttpClient

**Named HTTP client:**

```csharp
// Program.cs (v4)
builder.Services.AddClientCredentialsHttpClient("api-client",
    ClientCredentialsClientName.Parse("api-client"),
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com");
    });

// The first parameter is the HTTP client name
// The second parameter is the token client name (from AddClient)

// v3 — second parameter is a plain string:
// builder.Services.AddClientCredentialsHttpClient("api-client", "api-client", ...);
```

**Typed HTTP client:**

```csharp
// Program.cs (v4)
builder.Services.AddHttpClient<ApiClient>(client =>
{
    client.BaseAddress = new Uri("https://api.example.com");
})
.AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("api-client"));

// v3 — plain string:
// .AddClientCredentialsTokenHandler("api-client");
```

### Worker Service / BackgroundService Pattern

```csharp
// Program.cs (v4)
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("api-client"), client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("worker");
        client.ClientSecret = ClientSecret.Parse("secret");
        client.Scope = Scope.Parse("api1");
    });

builder.Services.AddClientCredentialsHttpClient("api-client",
    ClientCredentialsClientName.Parse("api-client"),
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com");
    });

builder.Services.AddHostedService<DataSyncWorker>();

// DataSyncWorker.cs
public class DataSyncWorker : BackgroundService
{
    private readonly IHttpClientFactory _factory;

    public DataSyncWorker(IHttpClientFactory factory) => _factory = factory;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var client = _factory.CreateClient("api-client");
            var response = await client.GetAsync("/data", stoppingToken);
            // process response...

            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}
```

### Automatic Retry on 401 (V4)

`AddClientCredentialsHttpClient` in V4 includes an automatic retry handler that retries on `401` responses (forcing a fresh token). You can also add this manually:

```csharp
// v4
builder.Services.AddHttpClient<ApiClient>(client =>
{
    client.BaseAddress = new Uri("https://api.example.com");
})
.AddDefaultAccessTokenResiliency()
.AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("api-client"));

// v3 — plain string:
// .AddClientCredentialsTokenHandler("api-client");
```

## Token Caching

### Cache Lifetime Buffer

Tokens are cached until they expire, minus a `CacheLifetimeBuffer` to ensure the token is refreshed before it actually expires. This option is set on `ClientCredentialsTokenManagementOptions`, not on individual clients:

```csharp
// Client credentials cache options
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 120; // seconds (default: 60)
    options.CacheKeyPrefix = "myapp:tokens:"; // custom prefix for all cache keys
});
```

> `CacheLifetimeBuffer` and `CacheKeyPrefix` are global options — they apply to all client credentials token clients.

### V4: HybridCache

V4 uses `Microsoft.Extensions.Caching.Hybrid.HybridCache` for token caching. It is two-tier: in-memory L1 + optional remote L2. No explicit registration is required for the default in-memory tier.

```csharp
// Add a distributed remote cache (e.g., Redis) — HybridCache picks it up automatically as L2
// builder.Services.AddStackExchangeRedisCache(options => { ... });
```

### V3: IDistributedCache

V3 uses `IDistributedCache`:

```csharp
builder.Services.AddDistributedMemoryCache(); // Development
// Or for production:
// builder.Services.AddStackExchangeRedisCache(options => { ... });
```

### Custom Cache Key Generation (V4)

Implement `IClientCredentialsCacheKeyGenerator` for custom cache key construction:

```csharp
public class TenantCacheKeyGenerator : IClientCredentialsCacheKeyGenerator
{
    public string GenerateKey(ClientCredentialsTokenRequest request)
    {
        var tenant = GetCurrentTenant();
        return $"{tenant}:{request.ClientId}:{request.Scope}";
    }
}
```

## DPoP Integration

Configure DPoP proof tokens for both token acquisition and API calls:

### User Token Management with DPoP

```csharp
builder.Services.AddOpenIdConnectAccessTokenManagement(options =>
{
    options.DPoPJsonWebKey = """
    {
        "kty": "EC",
        "crv": "P-256",
        "d": "...",
        "x": "...",
        "y": "..."
    }
    """;
});
```

### Client Credentials with DPoP

```csharp
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("api-client"), client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("service");
        client.ClientSecret = ClientSecret.Parse("secret");
        client.DPoPJsonWebKey = """
        {
            "kty": "EC",
            "crv": "P-256",
            "d": "...",
            "x": "...",
            "y": "..."
        }
        """;
    });
```

The library automatically:

1. Creates DPoP proof tokens for token endpoint requests
2. Includes `dpop_jkt` at the authorize endpoint (user flow)
3. Attaches DPoP proof headers to API calls via the HTTP client handlers

## Blazor Server

Blazor Server cannot use `HttpContext` to access tokens (circuits outlive the initial HTTP request). Use the dedicated Blazor Server integration:

```csharp
// Program.cs
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();
```

### Custom Token Store

You must implement `IUserTokenStore` because the default cookie-based store is not compatible with Blazor Server circuits:

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

### Initializing Tokens

Tokens must be captured during the initial OIDC authentication flow (which happens over HTTP, before the circuit is established):

```csharp
// Program.cs
builder.Services.AddAuthentication()
    .AddOpenIdConnect("oidc", options =>
    {
        // ... OIDC config ...

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

## Client Assertions

Use `IClientAssertionService` to authenticate with signed JWTs instead of shared secrets. This is the recommended approach for production scenarios:

```csharp
public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;

    public JwtClientAssertionService(SigningCredentials signingCredentials)
    {
        _signingCredentials = signingCredentials;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var token = new SecurityTokenDescriptor
        {
            Issuer = "my_client_id",
            // IMPORTANT: Audience must be the authorization server's issuer URL,
            // NOT the token endpoint URL
            Audience = "https://identity.example.com",
            Expires = now.AddMinutes(5),
            IssuedAt = now,
            NotBefore = now,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = "my_client_id",
                ["jti"] = Guid.NewGuid().ToString()
            }
        };

        var handler = new JsonWebTokenHandler();
        var jwt = handler.CreateToken(token);

        return Task.FromResult<ClientAssertion?>(new ClientAssertion
        {
            Type = OidcConstants.ClientAssertionTypes.JwtBearer,
            Value = jwt
        });
    }
}
```

### Critical: Audience for Client Assertions

```csharp
// ❌ WRONG: Audience set to token endpoint URL
// This was the root cause of CVE-2025-27370 and CVE-2025-27371
Audience = "https://identity.example.com/connect/token"

// ✅ CORRECT: Audience must be the authorization server's issuer URL
Audience = "https://identity.example.com"
```

Register the service:

```csharp
builder.Services.AddSingleton<IClientAssertionService, JwtClientAssertionService>();
```

## Extensibility

### ITokenRequestCustomizer (V4)

Customize token requests dynamically, useful for multi-tenant scenarios. The customizer modifies `TokenRequestParameters` based on the outgoing HTTP request context:

```csharp
public class TenantTokenRequestCustomizer : ITokenRequestCustomizer
{
    private readonly ITenantResolver _tenantResolver;
    private readonly ITenantConfigStore _tenantConfigStore;

    public TenantTokenRequestCustomizer(
        ITenantResolver tenantResolver, ITenantConfigStore tenantConfigStore)
    {
        _tenantResolver = tenantResolver;
        _tenantConfigStore = tenantConfigStore;
    }

    public async Task<TokenRequestParameters> Customize(
        HttpRequestMessage httpRequest,
        TokenRequestParameters baseParameters,
        CancellationToken cancellationToken)
    {
        var tenantId = await _tenantResolver.GetTenantIdAsync(httpRequest, cancellationToken);
        var tenantConfig = await _tenantConfigStore.GetConfigurationAsync(tenantId, cancellationToken);

        return baseParameters with
        {
            Resource = Resource.Parse(tenantConfig.ApiResource),
            Scope = Scope.Parse(tenantConfig.RequiredScopes),
        };
    }
}
```

Register the customizer by passing it to the `Add*Handler` methods:

```csharp
var customizer = new TenantTokenRequestCustomizer(tenantResolver, tenantConfigStore);

services.AddHttpClient("client-credentials-http-client")
    .AddClientCredentialsTokenHandler(customizer,
        ClientCredentialsClientName.Parse("api-client"));

services.AddHttpClient("user-access-http-client")
    .AddUserAccessTokenHandler(customizer);
```

### ITokenRetriever (V4)

Replace the default token retrieval logic entirely. Implement `AccessTokenRequestHandler.ITokenRetriever` and wire it into an `AccessTokenRequestHandler`:

```csharp
public class CustomTokenRetriever(
    IClientCredentialsTokenManager clientCredentialsTokenManager,
    ClientCredentialsClientName clientName) : AccessTokenRequestHandler.ITokenRetriever
{
    public async Task<TokenResult<AccessTokenRequestHandler.IToken>> GetTokenAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        var param = new TokenRequestParameters
        {
            ForceTokenRenewal = request.GetForceRenewal() // for retry policies
        };

        var result = await clientCredentialsTokenManager
            .GetAccessTokenAsync(clientName, param, ct);

        if (!result.Succeeded)
        {
            return result.FailedResult;
        }

        return TokenResult.Success(result.Token);
    }
}
```

Register via `AddHttpMessageHandler`:

```csharp
services.AddHttpClient<ApiClient>()
    .AddDefaultAccessTokenResiliency()
    .AddHttpMessageHandler(provider =>
    {
        var retriever = new CustomTokenRetriever(...);
        var logger = provider.GetRequiredService<ILogger<AccessTokenRequestHandler>>();
        var dPoPProofService = provider.GetRequiredService<IDPoPProofService>();
        var dPoPNonceStore = provider.GetRequiredService<IDPoPNonceStore>();

        return new AccessTokenRequestHandler(
            tokenRetriever: retriever,
            dPoPNonceStore: dPoPNonceStore,
            dPoPProofService: dPoPProofService,
            logger: logger);
    });
```

## Complete Example: Web App with User and Client Credentials

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// User token management via OIDC
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web_app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("api1");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
});

builder.Services.AddOpenIdConnectAccessTokenManagement();

// User token HTTP client
builder.Services.AddUserAccessTokenHttpClient("user-api",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com");
    });

// Client credentials for service-to-service (v4 types)
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("service-client"), client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("web_app_service");
        client.ClientSecret = ClientSecret.Parse("service_secret");
        client.Scope = Scope.Parse("backend.api");
    });

builder.Services.AddClientCredentialsHttpClient("service-api",
    ClientCredentialsClientName.Parse("service-client"),
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://backend.example.com");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// User-context API call
app.MapGet("/user-data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("user-api");
    var response = await client.GetAsync("/data");
    return Results.Ok(await response.Content.ReadAsStringAsync());
}).RequireAuthorization();

// Service-to-service API call (no user context needed)
app.MapGet("/backend-data", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("service-api");
    var response = await client.GetAsync("/internal/data");
    return Results.Ok(await response.Content.ReadAsStringAsync());
});

app.Run();
```

## Common Anti-Patterns

- ❌ Manually managing token refresh with timers or background threads
- ✅ Use `AddOpenIdConnectAccessTokenManagement()` or `AddClientCredentialsTokenManagement()` — they handle refresh automatically

- ❌ Storing tokens in `HttpContext.Items` or static fields
- ✅ Use the built-in token store (session-based for user tokens, cache-based for client credentials)

- ❌ Creating `HttpClient` instances directly with `new HttpClient()` and manually setting the bearer header
- ✅ Use `IHttpClientFactory` with `.AddUserAccessTokenHandler()` or `.AddClientCredentialsTokenHandler()`

- ❌ Setting client assertion audience to the token endpoint URL
- ✅ Set audience to the authorization server's issuer URL (security vulnerability: CVE-2025-27370/CVE-2025-27371)

- ❌ Using `HttpContext` to access tokens in Blazor Server components
- ✅ Use `AddBlazorServerAccessTokenManagement<T>()` with a custom `IUserTokenStore`

- ❌ Setting `CacheLifetimeBuffer` to 0 (tokens used until exact expiration)
- ✅ Keep a buffer (default 60 seconds) to avoid using tokens that expire during transit

## Common Pitfalls

1. **Missing `offline_access` scope**: Without a refresh token, the library cannot renew expired user tokens. The user must re-authenticate when the access token expires.

2. **Missing `SaveTokens = true`**: Tokens from the OIDC flow are not persisted to the authentication properties. The library cannot retrieve or refresh them.

3. **Blazor Server HttpContext**: `HttpContext` is only available during the initial HTTP request that establishes the circuit. After that, it is `null`. Use the dedicated Blazor Server integration.

4. **Token client name mismatch**: The token client name in `AddClient("name", ...)` must match the name used in `AddClientCredentialsHttpClient("http-name", "name")` or `AddClientCredentialsTokenHandler("name")`.

5. **Cache invalidation on key rotation**: When DPoP keys are rotated, cached tokens bound to the old key become invalid. Ensure cache entries are invalidated when keys change.

6. **Multi-instance deployments**: The default in-memory cache is not shared across instances. Use a distributed cache (Redis, SQL) in production to avoid each instance fetching its own tokens.

7. **Token endpoint vs authority**: For client credentials, you can specify either `TokenEndpoint` (explicit URL) or the library can discover it from the OIDC discovery document. Do not set both unless you have a specific reason.

8. **Resiliency handler ordering**: The `AddDefaultAccessTokenResiliency()` handler retries on `401`. Ensure it is added before the token handler in the delegating handler chain so it can intercept the response. This is the default order when using the fluent API (e.g., `.AddDefaultAccessTokenResiliency().AddClientCredentialsTokenHandler(...)`).
