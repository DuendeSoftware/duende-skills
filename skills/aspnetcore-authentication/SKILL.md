---
name: aspnetcore-authentication
description: ASP.NET Core authentication middleware configuration including OpenID Connect, JWT Bearer, cookie authentication, authentication schemes, challenge/forbid flows, and external identity provider integration.
invocable: false
---

# ASP.NET Core Authentication

## When to Use This Skill

Use this skill when:
- Configuring OIDC authentication in an ASP.NET Core web application
- Setting up JWT Bearer authentication for an API
- Managing authentication schemes (cookies, OIDC, JWT, external providers)
- Implementing challenge, sign-in, sign-out, and forbid flows
- Debugging authentication failures (401s, redirect loops, claim mapping issues)
- Integrating with Duende IdentityServer as an OpenID Connect provider
- Configuring token validation parameters

## Core Principles

1. **Authentication ≠ Authorization** — Authentication establishes *who* the user is. Authorization (see `aspnetcore-authorization`) determines *what* they can do.
2. **Scheme-Based Architecture** — ASP.NET Core authentication is built around named schemes. Each scheme has a handler that knows how to authenticate, challenge, and sign out.
3. **Cookies for Web Apps, JWT for APIs** — Web applications use cookie authentication (with OIDC for login). APIs use JWT Bearer or introspection.
4. **Never Roll Your Own** — Use the built-in OIDC and JWT Bearer handlers. They handle nonce validation, key rotation, token validation, and dozens of edge cases.
5. **Claim Type Mapping Matters** — The OIDC handler maps JWT claim types to .NET claim types by default. Disable this for predictable claim names.

## Related Skills

- `aspnetcore-authorization` — Policy-based authorization after authentication
- `identityserver-configuration` — Server-side client and resource configuration
- `oauth-oidc-protocols` — Protocol fundamentals underlying these handlers
- `token-management` — Automatic token refresh with Duende.AccessTokenManagement
- `duende-bff` — BFF pattern for SPAs that builds on top of these authentication primitives

---

## Pattern 1: OIDC Authentication for Web Applications

The most common pattern — a server-rendered web app authenticating users via Duende IdentityServer:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.Name = "myapp";
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = true;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code"; // Authorization code flow

    // Map scopes to request
    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");
    options.Scope.Add("api1");
    options.Scope.Add("offline_access"); // For refresh tokens

    // Save tokens in the authentication cookie
    options.SaveTokens = true;

    // Disable Microsoft's JWT claim type mapping
    options.MapInboundClaims = false;

    // Where to get additional user claims
    options.GetClaimsFromUserInfoEndpoint = true;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
```

### Critical Settings Explained

| Setting | Why | Default |
|---------|-----|---------|
| `MapInboundClaims = false` | Prevents renaming `sub` → `http://schemas.xmlsoap.org/.../nameidentifier` | `true` (maps) |
| `SaveTokens = true` | Stores access/refresh tokens in the cookie for later API calls | `false` |
| `GetClaimsFromUserInfoEndpoint = true` | Fetches full profile claims from userinfo | `false` |
| `ResponseType = "code"` | Authorization code flow (PKCE is automatic in .NET 7+) | `"code"` (.NET 7+; was `"code id_token"` in earlier versions) |

---

## Pattern 2: JWT Bearer Authentication for APIs

APIs validate access tokens issued by IdentityServer:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api"; // Must match ApiResource name

        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

// Protect endpoints
app.MapGet("/products", () => Results.Ok())
    .RequireAuthorization();
```

### Multiple Audiences

When an API accepts tokens from multiple resources:

```csharp
options.TokenValidationParameters = new TokenValidationParameters
{
    ValidateAudience = true,
    ValidAudiences = new[] { "catalog-api", "shared-api" }
};
```

---

## Pattern 3: Reference Token Introspection

For APIs that validate reference tokens (opaque tokens) instead of JWTs:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddOAuth2Introspection("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";
    });
```

> Install the `Duende.AspNetCore.Authentication.JwtBearer` package which supports both JWT and reference token validation, switching automatically based on the token format.

### Combined JWT + Reference Token Support

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;

        // The Duende JWT handler can forward to introspection for reference tokens
        options.ForwardDefaultSelector = Selector.ForwardReferenceToken("introspection");
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";
    });
```

---

## Pattern 4: Understanding Authentication Schemes

ASP.NET Core uses named authentication schemes. Each scheme is handled by a specific handler.

### Default Schemes

```csharp
builder.Services.AddAuthentication(options =>
{
    // Used for [Authorize] attribute and User.Identity
    options.DefaultScheme = "Cookies";

    // Used when authentication is required (401 → redirect to login)
    options.DefaultChallengeScheme = "oidc";

    // Used when access is denied (403)
    options.DefaultForbidScheme = "oidc";

    // Used when signing in (setting the cookie after OIDC callback)
    options.DefaultSignInScheme = "Cookies";

    // Used when signing out
    options.DefaultSignOutScheme = "oidc";
});
```

### The Authentication Flow

```
Request → [UseAuthentication] → Cookie handler reads cookie
                                  ├─ Valid cookie → User is authenticated
                                  └─ No cookie → User is anonymous
         [UseAuthorization]  → [Authorize] attribute checks
                                  ├─ Authenticated → proceed
                                  └─ Not authenticated → Challenge
                                       └─ OIDC handler redirects to IdentityServer
                                            └─ User logs in → callback → cookie created
```

---

## Pattern 5: Claim Type Mapping

By default, the Microsoft OIDC handler remaps JWT claims to XML-based .NET claim types. This causes confusion:

### The Mapping Problem

| JWT Claim | .NET Default Mapping | After `MapInboundClaims = false` |
|-----------|---------------------|----------------------------------|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` | `sub` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` | `name` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` | `role` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` | `email` |

### The Fix — Always Disable Mapping

```csharp
// ✅ On the OIDC handler
options.MapInboundClaims = false;

// ✅ On the JWT Bearer handler
options.MapInboundClaims = false;

// ✅ Then tell ASP.NET Core which claims to use for Name and Role
options.TokenValidationParameters = new TokenValidationParameters
{
    NameClaimType = "name",
    RoleClaimType = "role"
};
```

> **Why this matters:** Without this, `User.FindFirst("sub")` returns `null` because the claim was renamed. You'd need to use the verbose XML URI instead.

---

## Pattern 6: OIDC Handler Events

The OIDC handler exposes events for customizing the authentication pipeline:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // ... other options ...

    options.Events = new OpenIdConnectEvents
    {
        // Customize the authorize request (e.g., add acr_values)
        OnRedirectToIdentityProvider = context =>
        {
            context.ProtocolMessage.AcrValues = "tenant:myorg";
            return Task.CompletedTask;
        },

        // Handle tokens after successful authentication
        OnTokenValidated = context =>
        {
            // Add custom claims to the identity
            var identity = context.Principal!.Identity as ClaimsIdentity;
            identity?.AddClaim(new Claim("app_version", "2.0"));
            return Task.CompletedTask;
        },

        // Handle sign-out redirect
        OnRedirectToIdentityProviderForSignOut = context =>
        {
            // Customize the logout redirect
            return Task.CompletedTask;
        },

        // Handle failures
        OnRemoteFailure = context =>
        {
            context.HandleResponse();
            context.Response.Redirect("/error?message=" +
                Uri.EscapeDataString(context.Failure?.Message ?? "Unknown error"));
            return Task.CompletedTask;
        }
    };
});
```

### Common Event Use Cases

| Event | Use Case |
|-------|----------|
| `OnRedirectToIdentityProvider` | Add `acr_values`, `login_hint`, or custom parameters |
| `OnTokenValidated` | Transform claims, load additional user data |
| `OnTokenResponseReceived` | Inspect raw token response |
| `OnRemoteFailure` | Custom error handling for failed logins |
| `OnSignedOutCallbackRedirect` | Custom post-logout redirect |

---

## Pattern 7: Sign-Out

Proper sign-out must clear both the local cookie and the IdentityServer session:

```csharp
// In a Razor Page or Controller
app.MapGet("/logout", async (HttpContext ctx) =>
{
    // Signs out of both the cookie and IdentityServer
    await ctx.SignOutAsync("Cookies");
    await ctx.SignOutAsync("oidc");
});
```

### The Sign-Out Flow

```
1. Client calls SignOutAsync("Cookies")    → clears local cookie
2. Client calls SignOutAsync("oidc")       → redirects to IS /connect/endsession
3. IdentityServer clears its session
4. IdentityServer notifies other clients   → front-channel or back-channel logout
5. IdentityServer redirects to PostLogoutRedirectUri
```

> **Important:** Calling only `SignOutAsync("Cookies")` without `SignOutAsync("oidc")` leaves the IdentityServer session active. The user will be silently re-authenticated on the next challenge.

---

## Pattern 8: Accessing Stored Tokens

When `SaveTokens = true`, the access token, refresh token, and ID token are stored in the authentication cookie:

```csharp
// In a controller or middleware
var accessToken = await HttpContext.GetTokenAsync("access_token");
var refreshToken = await HttpContext.GetTokenAsync("refresh_token");
var idToken = await HttpContext.GetTokenAsync("id_token");
var expiresAt = await HttpContext.GetTokenAsync("expires_at");

// Use the access token to call an API
httpClient.SetBearerToken(accessToken);
```

> **Better approach:** Use `Duende.AccessTokenManagement` (see `token-management` skill) which handles token refresh, caching, and rotation automatically instead of manually managing stored tokens.

---

## Common Pitfalls

### 1. Forgetting MapInboundClaims

```csharp
// ❌ WRONG — Claims have XML URIs, User.FindFirst("sub") returns null
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    // MapInboundClaims defaults to true
});

// ✅ CORRECT
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.MapInboundClaims = false;
});
```

### 2. Missing UseAuthentication Before UseAuthorization

```csharp
// ❌ WRONG — Authorization middleware can't see the authenticated user
app.UseAuthorization();
app.UseAuthentication(); // Too late!

// ✅ CORRECT — Authentication must come first
app.UseAuthentication();
app.UseAuthorization();
```

### 3. Not Clearing Scopes Before Adding

```csharp
// ❌ WRONG — Default scopes (openid, profile) are already added
options.Scope.Add("openid");   // Duplicate!
options.Scope.Add("profile");  // Duplicate!
options.Scope.Add("api1");

// ✅ CORRECT — Clear defaults first
options.Scope.Clear();
options.Scope.Add("openid");
options.Scope.Add("profile");
options.Scope.Add("api1");
```

### 4. Cookie Too Large (>4KB)

When `SaveTokens = true` and many claims are included, the cookie can exceed browser limits:

```csharp
// ✅ Solution 1: Use a server-side ITicketStore to move auth ticket out of the cookie.
// Implement ITicketStore backed by IDistributedCache (e.g., Redis), then register it:
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});
builder.Services.AddSingleton<ITicketStore, RedisTicketStore>(); // your ITicketStore impl

.AddCookie("Cookies", options =>
{
    // Wire the ITicketStore so the cookie only holds a session key, not the full ticket
    options.SessionStore = app.Services.GetRequiredService<ITicketStore>();
});
// Note: ITicketStore is in Microsoft.AspNetCore.Authentication.Cookies namespace.
// There is no built-in DistributedSessionStore class — you must implement ITicketStore.

// ✅ Solution 2: Filter claims stored in the cookie
.AddOpenIdConnect("oidc", options =>
{
    options.ClaimActions.DeleteClaims("sid", "idp", "auth_time", "amr");
});

// ✅ Solution 3: Use Duende BFF which handles this automatically
```

### 5. Redirect Loop After Login

Usually caused by the cookie not being set due to SameSite restrictions:

```csharp
// ✅ Check SameSite settings
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax; // Not Strict for OIDC callbacks
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});
```

---

## Resources

- [ASP.NET Core Authentication — Microsoft Docs](https://learn.microsoft.com/aspnet/core/security/authentication/)
- [OpenID Connect Handler — Microsoft Docs](https://learn.microsoft.com/aspnet/core/security/authentication/social/)
- [JWT Bearer Handler — Microsoft Docs](https://learn.microsoft.com/aspnet/core/security/authentication/jwt-bearer/)
- [Duende IdentityServer Quickstarts](https://docs.duendesoftware.com/identityserver/quickstarts/)
- [OIDC Handler Events — Duende Docs](https://docs.duendesoftware.com/identityserver/fundamentals/openid-connect-events/)
