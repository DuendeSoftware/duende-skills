# Implicit Flow Is Insecure — Use BFF with Authorization Code + PKCE

Your colleague is correct — **the implicit flow is deprecated and should not be used**. Here's why and what to do instead.

## Why Implicit Flow Is Insecure

The implicit flow (`response_type=token`) returns the access token directly in the **URL fragment** of the redirect (e.g., `https://app.example.com/callback#access_token=eyJ...`). This creates several critical security issues:

1. **Token exposure in URL fragments** — Access tokens appear in browser history, referrer headers, and server logs. Anyone with access to these can steal the token.
2. **No PKCE protection** — The implicit flow has no mechanism to prove that the entity receiving the token is the same one that initiated the request.
3. **No refresh tokens** — The implicit flow cannot issue refresh tokens, forcing users to re-authenticate frequently or use silent renewal hacks (hidden iframes) that are fragile and have their own security issues.
4. **The OAuth 2.0 Security BCP explicitly deprecates it** — The current best practice document (draft-ietf-oauth-security-topics) states: "The implicit grant MUST NOT be used."

## What to Do Instead: Backend-for-Frontend (BFF) Pattern

The recommended approach for SPAs is the **Backend-for-Frontend (BFF) pattern**:

1. Add a lightweight server-side component (ASP.NET Core) that acts as the BFF
2. The BFF uses **authorization code flow with PKCE** to authenticate with IdentityServer
3. **Tokens are kept server-side** in the BFF's session — they never reach the browser
4. The **SPA uses HTTP-only session cookies** to communicate with its BFF backend
5. The BFF proxies API calls, attaching the access token from its server-side session

```
┌──────┐  Cookie  ┌──────┐  Access Token  ┌──────┐
│  SPA │ ◄──────► │  BFF │ ──────────────► │  API │
│React │          │  .NET│                  │      │
└──────┘          └──────┘                  └──────┘
                      │
                      │ Auth Code + PKCE
                      ▼
               ┌──────────────┐
               │IdentityServer│
               └──────────────┘
```

### Why BFF Is Better

- **Tokens never reach the browser** — No XSS attack can steal them
- **Authorization code + PKCE** is used instead of implicit — code interception is prevented
- **Refresh tokens are stored server-side** — The BFF silently refreshes tokens without user interaction
- **HTTP-only secure cookies** prevent JavaScript access to the session

### Duende BFF Library

Duende provides a dedicated BFF library (`Duende.BFF`) that implements this pattern with minimal configuration:

```csharp
// Program.cs
builder.Services.AddBff();

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "__Host-bff";
    options.Cookie.SameSite = SameSiteMode.Strict;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "spa-bff";
    options.ClientSecret = "secret";
    options.ResponseType = "code"; // authorization code + PKCE
    options.SaveTokens = true;
    options.Scope.Add("api1");
    options.Scope.Add("offline_access");
});

var app = builder.Build();
app.UseBff();
app.UseAuthentication();
app.UseAuthorization();

// API endpoints are proxied through the BFF
app.MapRemoteBffApiEndpoint("/api/catalog", "https://api.example.com/catalog")
    .RequireAccessToken();
```
