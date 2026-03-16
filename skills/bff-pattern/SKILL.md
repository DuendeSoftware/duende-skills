---
name: bff-pattern
description: "Implementing the Backend for Frontend (BFF) pattern with Duende.BFF: architecture, OIDC integration, session management, anti-forgery, local and remote API proxying, YARP integration, token management, and Blazor support."
invocable: false
---

# Backend for Frontend (BFF) Pattern

## When to Use This Skill

- Architecting a secure browser-based application that calls APIs
- Setting up `AddBff()` and `UseBff()` in ASP.NET Core
- Configuring OIDC authentication with BFF (V4 `ConfigureOpenIdConnect` vs V3 manual setup)
- Understanding and using BFF management endpoints (`/bff/login`, `/bff/logout`, `/bff/user`)
- Protecting API calls with anti-forgery headers (`X-CSRF`)
- Exposing local APIs through the BFF host with `.AsBffApiEndpoint()`
- Proxying remote API calls with `MapRemoteBffApiEndpoint` and token attachment
- Integrating YARP as a reverse proxy with BFF token management
- Adding Blazor Server or Blazor WASM support with BFF

## Why the BFF Pattern

Browser-based applications (SPAs, Blazor WASM) should not handle access tokens directly. Tokens in the browser are vulnerable to:

- **Cross-site scripting (XSS)** — JavaScript can steal tokens from `localStorage` or `sessionStorage`
- **Token exfiltration** — compromised dependencies can extract tokens
- **No secure storage** — browsers have no equivalent of a server-side session store

The BFF pattern keeps tokens on the server side. The browser authenticates via cookies to the BFF host, and the BFF attaches tokens to upstream API calls on behalf of the user.

### Architecture

```
Browser  ──cookie──►  BFF Host  ──access token──►  API
  (SPA)                (ASP.NET Core)               (Resource Server)
```

The BFF host:

1. Handles OIDC authentication (login/logout)
2. Stores tokens in the server-side session
3. Provides management endpoints for the frontend
4. Proxies API calls, attaching the appropriate access token
5. Enforces anti-forgery protection on all API calls

## Setting Up BFF

### V4 Setup (Recommended)

In V4, `AddBff()` provides a fluent API with `ConfigureOpenIdConnect()` and `ConfigureCookies()` that auto-registers authentication handlers:

```bash
dotnet add package Duende.BFF
```

```csharp
// Program.cs
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "spa";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
        options.GetClaimsFromUserInfoEndpoint = true;
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
    });

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// BFF management endpoints are auto-registered in V4
app.MapFallbackToFile("index.html");

app.Run();
```

### V3 Setup

In V3, you manually configure authentication handlers and explicitly map management endpoints:

```csharp
// Program.cs
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
    options.DefaultSignOutScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "__Host-bff";
    options.Cookie.SameSite = SameSiteMode.Strict;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "spa";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("api1");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
    options.GetClaimsFromUserInfoEndpoint = true;
});

builder.Services.AddBff();

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints(); // Required in V3

app.Run();
```

### Key Differences V4 vs V3

| Feature               | V4                                                | V3                                          |
| --------------------- | ------------------------------------------------- | ------------------------------------------- |
| Auth handler setup    | `ConfigureOpenIdConnect()` / `ConfigureCookies()` | Manual `AddCookie()` / `AddOpenIdConnect()` |
| Management endpoints  | Auto-registered                                   | `MapBffManagementEndpoints()` required      |
| Remote API token type | `RequiredTokenType.User`                          | `TokenType.User`                            |

## BFF Management Endpoints

BFF provides built-in endpoints for session management at the `/bff/` path prefix:

### `/bff/login`

Triggers the OIDC challenge. The frontend redirects the browser here:

```javascript
// Frontend JavaScript
window.location.href = "/bff/login?returnUrl=/app";
```

The `returnUrl` parameter determines where the user is redirected after authentication. It must be a local URL.

### `/bff/user`

Returns the current user's claims as a JSON array. Must include the `X-CSRF` anti-forgery header:

```javascript
// Frontend JavaScript
const response = await fetch("/bff/user", {
  headers: { "X-CSRF": "1" },
});

if (response.ok) {
  const claims = await response.json();
  // claims is an array of { type, value } objects
  // [
  //   { "type": "sub", "value": "88421113" },
  //   { "type": "name", "value": "Bob" },
  //   { "type": "bff:logout_url", "value": "/bff/logout?sid=..." },
  //   { "type": "bff:session_expires_in", "value": "3600" },
  //   { "type": "bff:session_state", "value": "..." }
  // ]
} else if (response.status === 401) {
  // User is not authenticated
}
```

**Special management claims** included in the response:

| Claim                    | Purpose                                        |
| ------------------------ | ---------------------------------------------- |
| `bff:logout_url`         | Pre-built logout URL with CSRF `sid` parameter |
| `bff:session_expires_in` | Seconds until session expires                  |
| `bff:session_state`      | Session state for change detection             |

**Anonymous behavior**: Returns `401` by default. Can be changed to return `200` with `null` body via `BffOptions.AnonymousSessionResponse`.

**Session sliding**: Append `?slide=false` to prevent extending the session when checking user status.

### `/bff/logout`

Logs out the user. Requires CSRF protection via the `sid` query parameter (provided in the `bff:logout_url` claim from `/bff/user`):

```javascript
// Frontend JavaScript — use the bff:logout_url from /bff/user
const logoutUrl = claims.find((c) => c.type === "bff:logout_url").value;
window.location.href = logoutUrl;
```

By default, logout revokes refresh tokens (`BffOptions.RevokeRefreshTokenOnLogout = true`).

```csharp
// ❌ WRONG: Hardcoded logout URL without sid — CSRF protection will reject this
window.location.href = "/bff/logout";

// ✅ CORRECT: Use the bff:logout_url from the /bff/user response
window.location.href = claims.find(c => c.type === "bff:logout_url").value;
```

## Anti-Forgery Protection

BFF requires an anti-forgery header on all API calls to prevent cross-site request forgery. The header name defaults to `X-CSRF` with value `1`.

### How It Works

1. The browser sends the `X-CSRF: 1` header with every API request
2. BFF middleware validates the header is present
3. The presence of a custom header triggers a CORS preflight request, which prevents cross-origin sites from making authenticated requests

### Configuration

```csharp
// Program.cs
builder.Services.AddBff(options =>
{
    options.AntiForgeryHeaderName = "X-CSRF";   // default
    options.AntiForgeryHeaderValue = "1";        // default
});
```

### Frontend Integration

```javascript
// All API calls through the BFF must include the anti-forgery header
async function callApi(url, method = "GET", body = null) {
  const options = {
    method,
    headers: {
      "X-CSRF": "1",
      "Content-Type": "application/json",
    },
  };
  if (body) options.body = JSON.stringify(body);
  return fetch(url, options);
}
```

## Local APIs

Local APIs are endpoints hosted in the BFF application itself. Mark them with `.AsBffApiEndpoint()` to enforce anti-forgery checks:

```csharp
// Program.cs
app.MapGet("/api/data", (ClaimsPrincipal user) =>
{
    var sub = user.FindFirst("sub")?.Value;
    return Results.Ok(new { message = $"Hello {sub}" });
})
.RequireAuthorization()
.AsBffApiEndpoint();
```

### Controller-Based Local APIs

Use the `[BffApi]` attribute:

```csharp
[BffApi]
[Authorize]
[ApiController]
[Route("api/[controller]")]
public class DataController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        var sub = User.FindFirst("sub")?.Value;
        return Ok(new { message = $"Hello {sub}" });
    }
}
```

### Skipping Anti-Forgery

For specific endpoints that cannot send the anti-forgery header (e.g., webhook receivers):

```csharp
// V2+ / V3
app.MapPost("/api/webhook", (WebhookPayload payload) => Results.Ok())
    .AsBffApiEndpoint()
    .SkipAntiforgery();
```

## Remote APIs

Remote APIs are external services that the BFF proxies requests to, attaching access tokens automatically.

### Simple Remote API Mapping

```csharp
// Program.cs
app.MapRemoteBffApiEndpoint("/api/external", "https://api.example.com/data")
    .RequireAccessToken(RequiredTokenType.User); // V4
    // .RequireAccessToken(TokenType.User);      // V3
```

### Token Attachment Modes

| Mode           | Description                                            | Use Case                                                |
| -------------- | ------------------------------------------------------ | ------------------------------------------------------- |
| `User`         | Attach user access token; fail if not available        | User-specific API calls                                 |
| `Client`       | Attach client credentials token                        | Machine-to-machine calls                                |
| `UserOrClient` | Prefer user token, fall back to client token           | APIs that serve both authenticated and service contexts |
| `UserOrNone`   | Attach user token if available, proceed without if not | Optional authentication                                 |

```csharp
// User token required
app.MapRemoteBffApiEndpoint("/api/user-data", "https://api.example.com/user")
    .RequireAccessToken(RequiredTokenType.User);

// Client credentials
app.MapRemoteBffApiEndpoint("/api/config", "https://api.example.com/config")
    .RequireAccessToken(RequiredTokenType.Client);

// Prefer user, fall back to client
app.MapRemoteBffApiEndpoint("/api/mixed", "https://api.example.com/mixed")
    .RequireAccessToken(RequiredTokenType.UserOrClient);
```

## YARP Integration

For complex proxying scenarios, BFF integrates with YARP (Yet Another Reverse Proxy).

### Setup

```csharp
// Program.cs
builder.Services.AddBff();

var proxyBuilder = builder.Services.AddReverseProxy()
    .AddBffExtensions(); // Register BFF token management for YARP

// Configure routes in code
proxyBuilder.LoadFromMemory(
    routes:
    [
        new RouteConfig
        {
            RouteId = "api",
            ClusterId = "api-cluster",
            Match = new RouteMatch { Path = "/api/{**catch-all}" }
        }
        .WithAccessToken(TokenType.User)
        .WithAntiforgeryCheck()
    ],
    clusters:
    [
        new ClusterConfig
        {
            ClusterId = "api-cluster",
            Destinations = new Dictionary<string, DestinationConfig>
            {
                ["default"] = new DestinationConfig
                {
                    Address = "https://api.example.com"
                }
            }
        }
    ]
);

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapReverseProxy(proxyApp =>
{
    proxyApp.UseAntiforgeryCheck(); // Required for YARP anti-forgery
});

app.Run();
```

### YARP Configuration via appsettings.json

When using JSON configuration, set BFF metadata on routes:

```json
{
  "ReverseProxy": {
    "Routes": {
      "api-route": {
        "ClusterId": "api-cluster",
        "Match": { "Path": "/api/{**catch-all}" },
        "Metadata": {
          "Duende.Bff.Yarp.TokenType": "User",
          "Duende.Bff.Yarp.AntiforgeryCheck": "true"
        }
      }
    },
    "Clusters": {
      "api-cluster": {
        "Destinations": {
          "default": { "Address": "https://api.example.com" }
        }
      }
    }
  }
}
```

### YARP Code Configuration Extensions

| Extension                         | Purpose                        |
| --------------------------------- | ------------------------------ |
| `WithAccessToken(TokenType.User)` | Attach user access token       |
| `WithAntiforgeryCheck()`          | Enable anti-forgery validation |
| `WithOptionalUserAccessToken()`   | Attach user token if available |

## Token Management in BFF

BFF integrates with Duende.AccessTokenManagement to handle token refresh automatically.

### Accessing Tokens Manually

```csharp
// In a local API endpoint
app.MapGet("/api/call-external", async (HttpContext context) =>
{
    var token = await context.GetUserAccessTokenAsync();
    // Use token.AccessToken to call external APIs
});
```

### Named HTTP Clients

```csharp
// Program.cs
builder.Services.AddUserAccessTokenHttpClient("external-api",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com");
    });

// In a handler or controller
app.MapGet("/api/call-external", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("external-api");
    var response = await client.GetAsync("/data");
    return Results.Ok(await response.Content.ReadAsStringAsync());
});
```

## Blazor Integration

### Blazor Server

```csharp
// Program.cs
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "blazor-server";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    })
    .AddBlazorServer();
```

`AddBlazorServer()` integrates BFF session management with Blazor Server's circuit model.

### Blazor WASM (Client)

```csharp
// Server-side Program.cs
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        // ... OIDC config
    })
    .AddBffBlazorClient();

// Client-side Program.cs (WASM)
builder.Services.AddBffBlazorClient(options =>
{
    options.RemoteApiPath = "/api/remote";
    options.Polling = new BffBlazorClientPollingOptions
    {
        Interval = TimeSpan.FromMinutes(1)
    };
});

builder.Services.AddLocalApiHttpClient<WeatherClient>();
```

`AddLocalApiHttpClient<T>()` creates a typed HTTP client for the Blazor WASM frontend that routes through the BFF host.

### BffBlazorServerOptions

| Option            | Default    | Purpose                           |
| ----------------- | ---------- | --------------------------------- |
| `PollingInterval` | 60 seconds | How often to check session status |

### BffBlazorClientOptions

| Option             | Default       | Purpose                         |
| ------------------ | ------------- | ------------------------------- |
| `RemoteApiPath`    | `/api/remote` | Base path for remote API calls  |
| `BaseAddress`      | (from host)   | Base address for API calls      |
| `Polling.Interval` | 60 seconds    | Session status polling interval |

## BffOptions Reference

| Option                             | Default    | Purpose                                         |
| ---------------------------------- | ---------- | ----------------------------------------------- |
| `AntiForgeryHeaderName`            | `"X-CSRF"` | Name of the anti-forgery header                 |
| `AntiForgeryHeaderValue`           | `"1"`      | Expected value of the anti-forgery header       |
| `ManagementBasePath`               | `"/bff"`   | Base path for management endpoints              |
| `RevokeRefreshTokenOnLogout`       | `true`     | Revoke refresh tokens on logout                 |
| `AnonymousSessionResponse`         | (null)     | Response for `/bff/user` when anonymous         |
| `BackchannelLogoutAllUserSessions` | `false`    | Logout all sessions on backchannel notification |

## Common Anti-Patterns

- ❌ Storing access tokens in browser `localStorage` or `sessionStorage`
- ✅ Use the BFF pattern to keep tokens on the server side

- ❌ Omitting the `X-CSRF` header on API calls to the BFF
- ✅ Always include `X-CSRF: 1` on all fetch calls through the BFF

- ❌ Hardcoding `/bff/logout` without the `sid` parameter
- ✅ Use the `bff:logout_url` from the `/bff/user` response

- ❌ Using `RequireAccessToken` without requesting `offline_access` scope
- ✅ Request `offline_access` to enable token refresh; otherwise expired tokens cause failures

- ❌ Calling `MapBffManagementEndpoints()` in V4 (unnecessary, auto-registered)
- ✅ V4 auto-registers management endpoints; only V3 needs explicit mapping

- ❌ Forgetting `UseAntiforgeryCheck()` in the YARP pipeline
- ✅ Always call `proxyApp.UseAntiforgeryCheck()` inside `MapReverseProxy`

## Common Pitfalls

1. **Cookie `SameSite` configuration**: Use `SameSiteMode.Strict` for the authentication cookie to prevent CSRF. If the frontend and BFF are on different subdomains, you may need `Lax` instead, but `Strict` is preferred.

2. **Missing `SaveTokens = true`**: Without `SaveTokens = true` on the OIDC handler, tokens are not stored in the session and BFF cannot attach them to API calls. This manifests as `null` access tokens on upstream requests.

3. **CORS and the anti-forgery header**: The `X-CSRF` header triggers a CORS preflight request. If your frontend is served from the same origin as the BFF (recommended), this is not an issue. Cross-origin setups require explicit CORS configuration.

4. **Session expiration vs token expiration**: The session cookie and the access token have independent lifetimes. BFF auto-refreshes access tokens using refresh tokens, but if the session expires, the user must re-authenticate even if the refresh token is still valid.

5. **YARP metadata key typos**: The metadata keys (`Duende.Bff.Yarp.TokenType`, `Duende.Bff.Yarp.AntiforgeryCheck`) are case-sensitive strings. Typos fail silently — no token attachment, no anti-forgery check.

6. **Blazor Server circuit lifetime**: Blazor Server circuits can outlive the HTTP session. `AddBlazorServer()` handles synchronization, but long-lived circuits may encounter expired sessions. Configure appropriate polling intervals.

7. **Remote API path matching**: `MapRemoteBffApiEndpoint("/api/external", ...)` matches the path prefix. Requests to `/api/external/sub/path` are forwarded to `https://api.example.com/data/sub/path`. Verify the upstream API expects this path structure.
