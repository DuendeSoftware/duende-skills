# Implicit Flow is Deprecated — Use BFF Pattern Instead

## Your Colleague is Correct

The implicit flow is **deprecated** and should not be used. The OAuth 2.0 Security Best Current Practice (BCP) and the OAuth 2.0 for Browser-Based Apps draft specification explicitly recommend against it.

## Why Implicit Flow is Insecure

In the implicit flow, tokens are returned **directly in the URL fragment** (after the `#`):

```
https://your-spa.example.com/callback#access_token=eyJ...&token_type=bearer&expires_in=3600
```

Problems:
1. **Tokens in browser history** — The URL fragment containing the token is stored in browser history
2. **Tokens in referrer headers** — If the page has any external resources, the token can leak via the `Referer` header
3. **No PKCE protection** — The implicit flow has no mechanism for proof-key validation
4. **Token exposure in logs** — URL fragments may be logged by proxies, CDNs, or browser extensions
5. **No refresh tokens** — The implicit flow cannot issue refresh tokens, forcing the client to use hidden iframes for silent renew (which is fragile and has been broken by third-party cookie restrictions)

## The Correct Approach: Backend-for-Frontend (BFF) Pattern

For SPAs, the recommended architecture is the **Backend-for-Frontend (BFF)** pattern:

```
┌──────────┐     cookies      ┌──────────┐    access token    ┌──────────┐
│  React   │ ◄──────────────► │ BFF Host │ ◄───────────────► │   API    │
│  (SPA)   │   same-site      │ (server) │                    │          │
└──────────┘                   └──────────┘                    └──────────┘
                                    │
                        authorization code + PKCE
                                    │
                              ┌──────────────┐
                              │IdentityServer│
                              └──────────────┘
```

How it works:
1. The BFF server-side component performs the **authorization code flow with PKCE** against IdentityServer
2. **Tokens are kept server-side** in the BFF's session — they never reach the browser
3. The **SPA communicates with its BFF backend using HTTP-only, secure, same-site session cookies**
4. The BFF proxies API calls, attaching the access token from its session
5. Refresh tokens are handled server-side — no need for silent renew iframes

### Duende BFF

Duende provides the `Duende.BFF` NuGet package that implements this pattern:

```csharp
builder.Services.AddBff();
// ... OIDC configuration with authorization code + PKCE ...
app.UseBff();
```

This gives you session management, API proxying with automatic token attachment, and CSRF protection — all without exposing tokens to the browser.

## Key Takeaway

- **Never use implicit flow** — it's deprecated
- **Use authorization code flow with PKCE** — via a BFF server-side component
- **Keep tokens server-side** — the SPA communicates via session cookies, not bearer tokens
