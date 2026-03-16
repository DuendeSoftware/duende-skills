---
name: token-management
description: Token management patterns using Duende.AccessTokenManagement. Covers client credential token caching, user token refresh, token storage, HttpClientFactory integration, DPoP support, and common configuration pitfalls.
invocable: false
---

# Token Management

## When to Use This Skill

Use this skill when:
- Building a .NET worker service or daemon that calls APIs using the client credentials flow
- Building an ASP.NET Core web application that calls APIs on behalf of the currently logged-in user
- Integrating `Duende.AccessTokenManagement` or `Duende.AccessTokenManagement.OpenIdConnect` with `IHttpClientFactory`
- Configuring token caching — in-memory, distributed (Redis), or hybrid — for machine-to-machine tokens
- Adding DPoP (Demonstrating Proof-of-Possession) key binding to access tokens
- Implementing API-to-API delegation where a downstream service calls further APIs with either user tokens or client credentials
- Revoking refresh tokens on user sign-out

## Core Principles

1. **Prefer Automatic Over Manual** — Use `IHttpClientFactory`-integrated clients; they acquire, cache, refresh, and attach tokens transparently. Call `GetAccessTokenAsync` manually only when the factory pattern is insufficient.
2. **Never Cache Tokens in Code** — The library owns the cache. Do not store tokens in instance fields, static variables, or application-managed caches. Call the service on every request and let it serve from cache.
3. **`SaveTokens = true` Is Required for User Tokens** — The OIDC handler must persist tokens into the authentication session. This is the most common misconfiguration.
4. **Refresh Tokens Must Be Revoked at Sign-Out** — Call `e.HttpContext.RevokeRefreshTokenAsync()` in `OnSigningOut` to revoke the refresh token at the authorization server, preventing reuse after logout.
5. **v4 Uses `HybridCache`; v3 Uses `IDistributedCache`** — The caching layer changed between major versions. v4's `HybridCache` is two-tier and automatic; v3 requires an explicit `AddDistributedMemoryCache()` or Redis registration.
6. **Resiliency Is Included in `AddClientCredentialsHttpClient`** — This registration adds a once-retry handler for `401 Unauthorized` responses (handles token expiry and DPoP nonce challenges). When using `AddClientCredentialsTokenHandler` directly, add it explicitly.

## Related Skills

- `aspnetcore-authentication` — cookie and OIDC handler setup required for user token management
- `identityserver-configuration` — configuring the authorization server that issues tokens
- `oauth-oidc-protocols` — protocol fundamentals underlying client credentials and refresh token flows
- `duende-bff` — BFF pattern integrates this library automatically for proxied API calls

---

## Pattern 1: Machine-to-Machine (Client Credentials) — Worker Services

### Package

```bash
dotnet add package Duende.AccessTokenManagement
```

### Registration

```csharp
// ✅ Register one or more named client definitions
services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.company.com/connect/token");
        client.ClientId = ClientId.Parse("6f59b670-990f-4ef7-856f-0dd584ed1fac");
        client.ClientSecret = ClientSecret.Parse("d0c17c6a-ba47-4654-a874-f6d576cdf799");
        client.Scope = Scope.Parse("catalog inventory");
    })
    .AddClient("invoice.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.company.com/connect/token");
        client.ClientId = ClientId.Parse("ff8ac57f-5ade-47f1-b8cd-4c2424672351");
        client.ClientSecret = ClientSecret.Parse("4dbbf8ec-d62a-4639-b0db-aa5357a0cf46");
        client.Scope = Scope.Parse("invoice customers");
    });
```

Available client options:
- `TokenEndpoint` — URL of the OAuth token endpoint
- `ClientId` / `ClientSecret` — client credentials
- `ClientCredentialStyle` — `AuthorizationHeader` (default) or `PostBody`
- `Scope` — requested scope (optional; overridable per request)
- `Resource` — resource indicator per RFC 8707 (optional)
- `HttpClientName` — custom backchannel HTTP client name from the factory
- `DPoPJsonWebKey` — JWK for DPoP-bound tokens (see Pattern 5)

### Automatic via HttpClientFactory (Recommended)

```csharp
// ✅ Named client — token acquired, cached, and attached automatically
services.AddClientCredentialsHttpClient(
    "invoices",
    ClientCredentialsClientName.Parse("invoice.client"),
    client => { client.BaseAddress = new Uri("https://apis.company.com/invoice/"); });

// ✅ Typed client — identical behaviour, strongly typed
services.AddHttpClient<CatalogClient>(client =>
    {
        client.BaseAddress = new Uri("https://apis.company.com/catalog/");
    })
    .AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("catalog.client"));
```

Usage — no token code required at the call site:

```csharp
public sealed class WorkerHttpClient(IHttpClientFactory factory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // ✅ Token acquired, cached, and refreshed transparently
            var client = factory.CreateClient("invoices");
            var response = await client.GetAsync("list", stoppingToken);
            // ...
        }
    }
}
```

> **Resiliency handler** — `AddClientCredentialsHttpClient` automatically adds a resiliency handler that retries once on `401 Unauthorized`. This covers token expiry and DPoP nonce challenges. When using `AddClientCredentialsTokenHandler` directly, add it explicitly:
>
> ```csharp
> services.AddHttpClient<CatalogClient>(...)
>     .AddDefaultAccessTokenResiliency()
>     .AddClientCredentialsTokenHandler("catalog.client");
> ```

### Manual Token Retrieval (Advanced)

```csharp
// ✅ Inject IClientCredentialsTokenManager (v4)
public sealed class WorkerManual(
    IHttpClientFactory factory,
    IClientCredentialsTokenManager tokenManager) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var tokenResult = await tokenManager.GetAccessTokenAsync(
                ClientCredentialsClientName.Parse("catalog.client"),
                ct: stoppingToken);

            if (!tokenResult.Succeeded)
            {
                // log and handle — do not call .GetToken() without checking first
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                continue;
            }

            var token = tokenResult.GetToken();
            var client = factory.CreateClient();
            client.SetBearerToken(token.AccessToken.ToString());
            var response = await client.GetAsync("https://apis.company.com/catalog/list", stoppingToken);
            // ...
        }
    }
}
```

> In v3, the service was `IClientCredentialsTokenManagementService` and the result was read via `.Value`. In v4 it is `IClientCredentialsTokenManager` and the result is `TokenResult<ClientCredentialsToken>` — use `.Succeeded` / `.GetToken()`.

---

## Pattern 2: User Token Management — Web Applications

### Package

```bash
dotnet add package Duende.AccessTokenManagement.OpenIdConnect
```

### Registration

```csharp
// ✅ Full setup: cookie + OIDC handler + token management
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Cookie.Name = "web";
        // ✅ Revoke refresh token at sign-out
        options.Events.OnSigningOut = async e =>
        {
            await e.HttpContext.RevokeRefreshTokenAsync();
        };
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.company.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access"); // ← required for refresh tokens

        options.GetClaimsFromUserInfoEndpoint = true;
        options.MapInboundClaims = false;

        // ✅ REQUIRED — persists access and refresh tokens into the auth session
        options.SaveTokens = true;
    });

// ✅ Adds all token management services
builder.Services.AddOpenIdConnectAccessTokenManagement();
```

> **`SaveTokens = true` is mandatory.** Without it, the library cannot read or refresh the user's access token. This is the most common misconfiguration causing `InvalidOperationException` at runtime.

### Automatic via HttpClientFactory (Recommended)

```csharp
// ✅ Named client using the current user's access token
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.company.com/invoices/");
    });

// ✅ Typed client using the current user's access token
builder.Services.AddHttpClient<InvoiceClient>(client =>
    {
        client.BaseAddress = new Uri("https://api.company.com/invoices/");
    })
    .AddUserAccessTokenHandler();

// ✅ Named client using a client credentials token (machine-to-machine, user-independent)
builder.Services.AddClientAccessTokenHttpClient(
    "masterdata.client",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.company.com/masterdata/");
    });

// ✅ Typed client using a client credentials token
builder.Services.AddHttpClient<MasterDataClient>(client =>
    {
        client.BaseAddress = new Uri("https://api.company.com/masterdata/");
    })
    .AddClientAccessTokenHandler();
```

Usage in a controller:

```csharp
public sealed class ApiController(IHttpClientFactory httpClientFactory) : Controller
{
    public async Task<IActionResult> CallApi(CancellationToken ct)
    {
        // ✅ Token attached automatically; refreshed silently if expired
        var client = httpClientFactory.CreateClient("invoices");
        var response = await client.GetAsync("list", ct);
        // ...
    }
}
```

### Manual Token Retrieval (Advanced)

```csharp
// ✅ v4 — inject IUserTokenManager
public sealed class HomeController(
    IHttpClientFactory httpClientFactory,
    IUserTokenManager userTokenManager) : Controller
{
    public async Task<IActionResult> CallApi(CancellationToken ct)
    {
        var token = await userTokenManager.GetAccessTokenAsync(User, ct: ct);
        var client = httpClientFactory.CreateClient();
        client.SetBearerToken(token.Value);
        var response = await client.GetAsync("https://api.company.com/invoices", ct);
        // ...
    }
}
```

`HttpContext` extension methods are also available:

```csharp
// ✅ User access token — refreshed automatically via refresh token if expired
var userToken = await HttpContext.GetUserAccessTokenAsync();

// ✅ Client credentials token — re-requested from the token server if expired
var clientToken = await HttpContext.GetClientAccessTokenAsync();

// ✅ Revoke refresh token explicitly (also wired into OnSigningOut above)
await HttpContext.RevokeRefreshTokenAsync();
```

### gRPC Support

Use `AddUserAccessTokenHandler` and `AddClientAccessTokenHandler` when registering typed gRPC clients:

```csharp
// ✅ gRPC client using the current user's access token
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.company.com");
})
.AddUserAccessTokenHandler();

// ✅ gRPC client using a client credentials token
builder.Services.AddGrpcClient<Inventory.InventoryClient>(o =>
{
    o.Address = new Uri("https://grpc.company.com");
})
.AddClientAccessTokenHandler();
```

---

## Pattern 3: Token Caching

### v4 — HybridCache (Default)

In v4, client credentials tokens are cached using `HybridCache` (ASP.NET Core 9+). It is two-tier: in-memory L1 + optional remote L2. No explicit registration is required for the default in-memory tier.

```csharp
// ✅ Add a distributed remote cache (e.g., Redis) — HybridCache picks it up automatically as L2
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

Global cache options:

```csharp
// ✅ Configure lifetime buffer and key prefix
services.AddClientCredentialsTokenManagement(options =>
{
    // Cache tokens 60 s before they expire to avoid serving a near-expired token
    options.CacheLifetimeBuffer = 60;
    options.CacheKeyPrefix = "MyApp.ATM::";
});
```

Default cache key format:

```
{CacheKeyPrefix}::{client_name}::hashed({scope})::hashed({resource})
```

`scope` and `resource` values are MD5-hashed to keep key length bounded. Implement `IClientCredentialsCacheKeyGenerator` to supply custom keys when adding custom `TokenRequestParameters`.

### v3 — IDistributedCache

```csharp
// ✅ v3: must explicitly register a distributed cache implementation
services.AddDistributedMemoryCache(); // development / single-instance only

// ✅ v3: Redis for production
services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis.company.com:6379";
});

services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60;
});
```

### Encrypting Cached Tokens (v4)

When sharing a remote cache with other applications, encrypt tokens at rest using a custom `IHybridCacheSerializer<ClientCredentialsToken>`:

```csharp
// ✅ Register the encrypted serializer for the ClientCredentialsToken type
services.AddHybridCache()
    .AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>();

services.AddDataProtection();

public sealed class EncryptedHybridCacheSerializer : IHybridCacheSerializer<ClientCredentialsToken>
{
    private readonly IDataProtector _protector;

    public EncryptedHybridCacheSerializer(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector("ClientCredentialsToken");
    }

    public ClientCredentialsToken Deserialize(ReadOnlySequence<byte> source)
    {
        var unprotected = _protector.Unprotect(source.ToArray());
        return JsonSerializer.Deserialize<ClientCredentialsToken>(unprotected)!;
    }

    public void Serialize(ClientCredentialsToken value, IBufferWriter<byte> target)
    {
        var json = JsonSerializer.SerializeToUtf8Bytes(value);
        target.Write(_protector.Protect(json));
    }
}
```

### Scoping a Custom Cache to This Library Only

```csharp
// ✅ Inject a custom HybridCache only for AccessTokenManagement (uses service keys)
services.AddKeyedSingleton<HybridCache>(
    ServiceProviderKeys.ClientCredentialsTokenCache,
    new MyCustomCacheImplementation());
```

---

## Pattern 4: Configuration Options

### `ClientCredentialsTokenManagementOptions`

```csharp
services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60;            // seconds subtracted from token lifetime in cache
    options.CacheKeyPrefix = "MyApp.ATM::";      // prefix for all cache keys
});
```

### `UserTokenManagementOptions`

```csharp
builder.Services.AddOpenIdConnectAccessTokenManagement(options =>
{
    // Override the OIDC challenge scheme if not using the default
    options.ChallengeScheme = "oidc";

    // Enable separate token stores per OIDC scheme (multi-provider setups)
    options.UseChallengeSchemeScopedTokens = false;

    // Scope and resource sent when requesting client credentials tokens from
    // the configured OIDC provider (cannot be inferred from OIDC metadata)
    options.ClientCredentialsScope = "api1 api2";
    options.ClientCredentialsResource = "urn:myapi";

    // How client credentials are sent to the token endpoint
    options.ClientCredentialStyle = ClientCredentialStyle.PostBody;

    // DPoP key for all user token requests from this application
    options.DPoPJsonWebKey = jwk;
});
```

### Per-Request Parameter Overrides

```csharp
// ✅ Force a fresh token even if a cached one exists
var token = await tokenManager.GetAccessTokenAsync(
    ClientCredentialsClientName.Parse("catalog.client"),
    new TokenRequestParameters { ForceRenewal = true },
    ct: stoppingToken);

// ✅ Override scope per user token request
var token = await userTokenManager.GetAccessTokenAsync(
    User,
    new UserTokenRequestParameters
    {
        Scope = "invoice:write",
        ForceRenewal = false,
        ChallengeScheme = "oidc"
    },
    ct: ct);
```

For `IHttpClientFactory` clients, parameters are wired at registration time:

```csharp
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    parameters: new UserTokenRequestParameters { ForceRenewal = true },
    configureClient: client => { client.BaseAddress = new Uri("https://api.company.com/invoices/"); });
```

---

## Pattern 5: DPoP (Demonstrating Proof-of-Possession)

DPoP binds an access token to an asymmetric key so that the token cannot be replayed by an attacker who steals it — they would also need the private key.

### Generate a JWK

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

// ✅ Generate once and store securely (Key Vault, configuration secrets)
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var jwk = JsonSerializer.Serialize(jwkKey);
```

Supported algorithms: RS, PS, and ES family keys (any JWK-compatible asymmetric key).

### Configure DPoP — User Token (OpenIdConnect)

```csharp
// ✅ Set the JWK at startup; the library handles everything else automatically
builder.Services.AddOpenIdConnectAccessTokenManagement(options =>
{
    options.DPoPJsonWebKey = jwk;
});
```

The library automatically:
- Adds `dpop_jkt` to the authorize endpoint request
- Sends a DPoP proof token on every token endpoint call (including token refreshes)
- Sends a DPoP proof token on every outgoing API call made via factory clients

### Configure DPoP — Client Credentials

```csharp
// ✅ Per-client DPoP key
services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.company.com/connect/token");
        client.ClientId = ClientId.Parse("...");
        client.ClientSecret = ClientSecret.Parse("...");
        client.DPoPJsonWebKey = jwk;
    });
```

### Custom DPoP Key Store

Implement `IDPoPKeyStore` to load or rotate the key at runtime rather than at startup:

```csharp
// ✅ Dynamic key resolution (e.g., from Azure Key Vault)
public sealed class KeyVaultDPoPKeyStore : IDPoPKeyStore
{
    private readonly IKeyVaultClient _keyVault;

    public KeyVaultDPoPKeyStore(IKeyVaultClient keyVault)
    {
        _keyVault = keyVault;
    }

    public async Task<string?> GetKeyAsync(string clientName, CancellationToken ct)
    {
        return await _keyVault.GetSecretAsync($"dpop-key-{clientName}", ct);
    }
}

// Registration
services.AddSingleton<IDPoPKeyStore, KeyVaultDPoPKeyStore>();
```

> **DPoP and user session size** — When using DPoP with `AddOpenIdConnectAccessTokenManagement`, the DPoP proof key is stored per user session inside the OIDC `state` parameter and the authentication cookie. This increases cookie and state size. Configure `StateDataFormat` on the OIDC options and `SessionStore` on the cookie options if this becomes a concern.

---

## Pattern 6: API-to-API Token Delegation

An API that receives a user request and needs to call a downstream API can use either the user's access token (delegation) or a client credentials token (machine identity). Both approaches integrate cleanly with `IHttpClientFactory`.

### Approach A — Forward the User Token (Downstream API Trusts Upstream's Token)

When the downstream API accepts the same audience as the upstream token, forward it directly:

```csharp
// In the calling API's Program.cs
builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddUserAccessTokenHttpClient(
    "downstream",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://downstream.company.com/api/");
    });
```

```csharp
// In the controller
public sealed class UpstreamController(IHttpClientFactory factory) : ControllerBase
{
    [HttpGet("data")]
    public async Task<IActionResult> GetData(CancellationToken ct)
    {
        // ✅ Forwards the current user's access token to the downstream API
        var client = factory.CreateClient("downstream");
        var response = await client.GetAsync("resource", ct);
        return Ok(await response.Content.ReadAsStringAsync(ct));
    }
}
```

### Approach B — Use a Dedicated Client Credentials Token

When the downstream API requires a service identity rather than a user identity:

```csharp
// In the calling API's Program.cs
services.AddClientCredentialsTokenManagement()
    .AddClient("downstream.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.company.com/connect/token");
        client.ClientId = ClientId.Parse("upstream-service");
        client.ClientSecret = ClientSecret.Parse("...");
        client.Scope = Scope.Parse("downstream:read");
    });

services.AddClientCredentialsHttpClient(
    "downstream",
    ClientCredentialsClientName.Parse("downstream.client"),
    client => { client.BaseAddress = new Uri("https://downstream.company.com/api/"); });
```

---

## Pattern 7: Dynamic Client Configuration

Use `IConfigureNamedOptions<ClientCredentialsClient>` when token endpoint configuration must be resolved at runtime — for example, from OIDC discovery:

```csharp
public sealed class ClientCredentialsConfigureOptions(DiscoveryCache cache)
    : IConfigureNamedOptions<ClientCredentialsClient>
{
    public void Configure(string? name, ClientCredentialsClient options)
    {
        if (name == "catalog.client")
        {
            // ✅ Resolve token endpoint from OIDC discovery document
            var disco = cache.GetAsync().GetAwaiter().GetResult();
            options.TokenEndpoint = new Uri(disco.TokenEndpoint);
            options.ClientId = ClientId.Parse("...");
            options.ClientSecret = ClientSecret.Parse("...");
            options.Scope = Scope.Parse("catalog");
        }
    }

    public void Configure(ClientCredentialsClient options) => Configure(string.Empty, options);
}

// Registration
services.AddClientCredentialsTokenManagement();
services.AddSingleton(new DiscoveryCache("https://sts.company.com"));
services.AddSingleton<IConfigureOptions<ClientCredentialsClient>, ClientCredentialsConfigureOptions>();
```

---

## Pattern 8: Custom Token Storage

### User Tokens — Replace the Default Cookie Session Store

By default, user access and refresh tokens are stored inside the ASP.NET Core authentication cookie. Replace `IUserTokenStore` when this is insufficient — for example, when using server-side sessions:

```csharp
// ✅ Register a custom implementation backed by server-side session storage
builder.Services.AddSingleton<IUserTokenStore, ServerSideSessionUserTokenStore>();
```

### Client Credentials — Replace the Cache Implementation

```csharp
// ✅ Override the entire cache with a custom IClientCredentialsTokenCache
services.AddSingleton<IClientCredentialsTokenCache, MyCustomTokenCache>();
```

---

## Pattern 9: Blazor Server Token Management

Blazor Server circuits outlive the initial HTTP request. Once a circuit is established, `HttpContext` is `null`, making the default cookie-based `IUserTokenStore` unusable. The library provides a dedicated extension for this scenario.

### Registration

```csharp
// Program.cs
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();
```

### Custom `IUserTokenStore` Implementation

You must implement `IUserTokenStore` backed by persistent storage (e.g., a database) so that tokens survive across circuit reconnections:

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

### Initializing Tokens via `OnTokenValidated`

Tokens must be captured during the initial OIDC authentication flow — the only point where `HttpContext` is available. Capture them in `OnTokenValidated` and persist to the custom store:

```csharp
// Program.cs
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

> **Why `HttpContext` is unavailable in Blazor circuits** — A Blazor Server circuit is a long-lived SignalR connection. The initial HTTP request that establishes the circuit has an `HttpContext`, but all subsequent interactions happen over the SignalR channel without one. Any code that reads `IHttpContextAccessor.HttpContext` or the authentication cookie store after circuit setup will find `null` or stale data.

---

## Pattern 10: Client Assertions

Use `IClientAssertionService` to authenticate with signed JWTs instead of shared client secrets. This is recommended for production deployments.

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
            // ✅ CRITICAL: Audience must be the authorization server's issuer URL,
            // NOT the token endpoint URL — see CVE-2025-27370 / CVE-2025-27371
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

// Registration
builder.Services.AddSingleton<IClientAssertionService, JwtClientAssertionService>();
```

### CRITICAL: Audience for Client Assertions

```csharp
// ❌ WRONG: Audience set to the token endpoint URL
// Root cause of CVE-2025-27370 and CVE-2025-27371
Audience = "https://identity.example.com/connect/token"

// ✅ CORRECT: Audience must be the authorization server's issuer URL
Audience = "https://identity.example.com"
```

> **CVE-2025-27370 / CVE-2025-27371** — These vulnerabilities were caused by setting the client assertion JWT audience to the token endpoint URL rather than the issuer URL. Authorization servers that accept both values are susceptible to token endpoint confusion attacks. Always set `Audience` to the issuer URL obtained from the OIDC discovery document (`issuer` claim).

---

## Pattern 11: Custom Token Request Customization

Use `ITokenRequestCustomizer` (v4) to dynamically modify token request parameters per outgoing HTTP request — useful for multi-tenant scenarios where different tenants require different API resources or scopes.

```csharp
public class TenantTokenRequestCustomizer : ITokenRequestCustomizer
{
    private readonly ITenantResolver _tenantResolver;
    private readonly ITenantConfigStore _tenantConfigStore;

    public TenantTokenRequestCustomizer(
        ITenantResolver tenantResolver,
        ITenantConfigStore tenantConfigStore)
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

        // ✅ Use 'with' expression to create a modified copy — do not mutate baseParameters
        return baseParameters with
        {
            Resource = Resource.Parse(tenantConfig.ApiResource),
            Scope = Scope.Parse(tenantConfig.RequiredScopes),
        };
    }
}
```

### Registration

Pass the customizer instance to the `Add*Handler` registration methods:

```csharp
var customizer = new TenantTokenRequestCustomizer(tenantResolver, tenantConfigStore);

// ✅ Client credentials client with customizer
services.AddHttpClient("client-credentials-http-client")
    .AddClientCredentialsTokenHandler(customizer,
        ClientCredentialsClientName.Parse("api-client"));

// ✅ User access token client with customizer
services.AddHttpClient("user-access-http-client")
    .AddUserAccessTokenHandler(customizer);
```

---

## Pattern 12: Custom Token Retrieval

Implement `AccessTokenRequestHandler.ITokenRetriever` to completely replace the default token retrieval logic — for example, to combine custom selection logic with the standard token manager:

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

### Registration via `AddHttpMessageHandler`

```csharp
services.AddHttpClient<ApiClient>()
    .AddDefaultAccessTokenResiliency()
    .AddHttpMessageHandler(provider =>
    {
        var retriever = new CustomTokenRetriever(
            provider.GetRequiredService<IClientCredentialsTokenManager>(),
            ClientCredentialsClientName.Parse("api-client"));
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

---

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
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "web";
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync();
    };
})
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

// User token HTTP client — attaches the logged-in user's access token
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

---

## Common Pitfalls

### 1. Missing `SaveTokens = true` for User Tokens

```csharp
// ❌ Tokens never stored in session — library throws InvalidOperationException at runtime
.AddOpenIdConnect("oidc", options =>
{
    // SaveTokens not set — defaults to false
});

// ✅ Always set it when using AddOpenIdConnectAccessTokenManagement
options.SaveTokens = true;
```

### 2. Missing `offline_access` Scope

```csharp
// ❌ No refresh token issued — access token expires and user must re-authenticate
options.Scope.Add("openid");
options.Scope.Add("profile");
// offline_access missing

// ✅
options.Scope.Add("offline_access");
```

### 3. Not Revoking Refresh Tokens at Sign-Out

```csharp
// ❌ Refresh token remains valid at the authorization server after sign-out
.AddCookie("cookie", options =>
{
    // No OnSigningOut handler — refresh token never revoked
});

// ✅
.AddCookie("cookie", options =>
{
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync();
    };
});
```

### 4. Caching Tokens Manually Alongside the Library

```csharp
// ❌ Double-caching — your cache won't stay in sync; stale token after expiry
private string? _cachedToken;

public async Task<string> GetToken()
{
    if (_cachedToken != null) return _cachedToken;
    var token = await _tokenManager.GetAccessTokenAsync(...);
    _cachedToken = token.AccessToken.ToString(); // never invalidated
    return _cachedToken;
}

// ✅ Call GetAccessTokenAsync every time — the library serves from cache transparently
public async Task<string> GetToken(CancellationToken ct)
{
    var result = await _tokenManager
        .GetAccessTokenAsync(ClientCredentialsClientName.Parse("my.client"), ct: ct)
        .GetToken();
    return result.AccessToken.ToString();
}
```

### 5. Calling `.GetToken()` Without Checking `Succeeded`

```csharp
// ❌ .GetToken() throws InvalidOperationException when token retrieval fails;
// the actual error is swallowed unless you inspect Succeeded first
var tokenResult = await tokenManager.GetAccessTokenAsync(...);
var token = tokenResult.GetToken(); // throws when Succeeded == false

// ✅ Check success before accessing the token value
var tokenResult = await tokenManager.GetAccessTokenAsync(...);
if (!tokenResult.Succeeded)
{
    logger.LogError("Failed to obtain access token");
    return Problem("Authentication failure", statusCode: StatusCodes.Status503ServiceUnavailable);
}
var token = tokenResult.GetToken();
```

### 6. Using `AddClientCredentialsTokenHandler` Without Resiliency

```csharp
// ❌ A 401 from an expired token is returned directly to the caller — no retry
services.AddHttpClient<CatalogClient>(...)
    .AddClientCredentialsTokenHandler("catalog.client");

// ✅ Add the resiliency handler before the token handler
services.AddHttpClient<CatalogClient>(...)
    .AddDefaultAccessTokenResiliency()
    .AddClientCredentialsTokenHandler("catalog.client");
```

### 7. v3 — Forgetting to Register a Distributed Cache

```csharp
// ❌ v3: no cache registered — runtime exception on first token request
services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client => { /* ... */ });
// Missing: services.AddDistributedMemoryCache();

// ✅ v3: always register a distributed cache (in-memory for dev, Redis for prod)
services.AddDistributedMemoryCache();
```

### 8. Regenerating DPoP Keys on Every Process Restart

```csharp
// ❌ New key generated on every restart — all previously issued DPoP-bound tokens
// become unusable, causing 401 errors until new tokens are obtained
var rsaKey = new RsaSecurityKey(RSA.Create(2048)); // ephemeral — lost on restart

// ✅ Load from stable, secure storage
var jwkJson = configuration["DPoP:JsonWebKey"]; // from Key Vault / secrets
services.AddClientCredentialsTokenManagement()
    .AddClient("my.client", client =>
    {
        client.DPoPJsonWebKey = jwkJson;
    });
```

### 9. Setting Client Assertion Audience to the Token Endpoint URL

```csharp
// ❌ Audience set to the token endpoint — security vulnerability
// Root cause of CVE-2025-27370 and CVE-2025-27371
Audience = "https://identity.example.com/connect/token"

// ✅ Audience must be the authorization server's issuer URL
Audience = "https://identity.example.com"
```

> CVE-2025-27370 and CVE-2025-27371 were caused by this exact mistake. Authorization servers that accept both values allow token endpoint confusion attacks.

### 10. Using `HttpContext` to Access Tokens in Blazor Server Components

```csharp
// ❌ HttpContext is null after circuit establishment — this will fail at runtime
var token = await HttpContext.GetUserAccessTokenAsync(); // throws NullReferenceException

// ✅ Use AddBlazorServerAccessTokenManagement<T>() with a custom IUserTokenStore
builder.Services.AddOpenIdConnectAccessTokenManagement()
    .AddBlazorServerAccessTokenManagement<ServerSideTokenStore>();
// Capture tokens in OnTokenValidated (see Pattern 9)
```

### 11. Setting `CacheLifetimeBuffer` to 0

```csharp
// ❌ Buffer set to 0 — tokens served until exact expiry; a token may expire
// in transit between retrieval and use at the API, causing unnecessary 401s
services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 0;
});

// ✅ Keep the default (60 s) or set a positive value that accounts for network latency
services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60; // default — refresh 60 s before expiry
});
```

---

## Version Reference: v3 → v4

| Area | v3 | v4 |
|---|---|---|
| Client credentials service | `IClientCredentialsTokenManagementService` | `IClientCredentialsTokenManager` |
| User token service | `IUserTokenManagementService` | `IUserTokenManager` |
| Token result type | `TokenResponse` — read `.Value` | `TokenResult<T>` — use `.Succeeded` / `.GetToken()` |
| Client name type | `string` | `ClientCredentialsClientName` (strongly typed) |
| Token cache | `IDistributedCache` (explicit `AddDistributedMemoryCache()` required) | `HybridCache` (automatic; picks up `IDistributedCache` as remote L2 tier) |
| Resiliency | Manual | `AddDefaultAccessTokenResiliency()` built into `AddClientCredentialsHttpClient` |

---

## Resources

- [Access Token Management Overview](https://docs.duendesoftware.com/accesstokenmanagement/)
- [Service Workers / Background Tasks](https://docs.duendesoftware.com/accesstokenmanagement/workers/)
- [Web Applications (User Tokens)](https://docs.duendesoftware.com/accesstokenmanagement/web-apps/)
- [Blazor Server](https://docs.duendesoftware.com/accesstokenmanagement/blazor-server/)
- [Advanced: Client Credentials Options](https://docs.duendesoftware.com/accesstokenmanagement/advanced/client-credentials/)
- [Advanced: User Token Options](https://docs.duendesoftware.com/accesstokenmanagement/advanced/user-tokens/)
- [Advanced: Client Assertions](https://docs.duendesoftware.com/accesstokenmanagement/advanced/client-assertions/)
- [Advanced: DPoP](https://docs.duendesoftware.com/accesstokenmanagement/advanced/dpop/)
- [Advanced: Extensibility](https://docs.duendesoftware.com/accesstokenmanagement/advanced/extensibility/)
- [v3 → v4 Upgrade Guide](https://docs.duendesoftware.com/accesstokenmanagement/upgrading/atm-v3-to-v4/)
- [NuGet: Duende.AccessTokenManagement](https://www.nuget.org/packages/Duende.AccessTokenManagement/)
- [NuGet: Duende.AccessTokenManagement.OpenIdConnect](https://www.nuget.org/packages/Duende.AccessTokenManagement.OpenIdConnect/)
- [GitHub: DuendeSoftware/foss (access-token-management)](https://github.com/DuendeSoftware/foss/tree/main/access-token-management)
