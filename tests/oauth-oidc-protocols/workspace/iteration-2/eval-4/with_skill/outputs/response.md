# SPA Security: Why Implicit Flow is Deprecated and What to Do Instead

## Your Colleague Is Right

The implicit flow **is deprecated and should not be used**. Here's why:

### Problems with Implicit Flow

1. **Tokens exposed in URL fragments**: In the implicit flow, the access token is returned directly in the URL fragment (`#access_token=...`) of the redirect back to the SPA. URL fragments can be:
   - Stored in browser history
   - Leaked via the `Referer` header
   - Intercepted by malicious browser extensions
   - Logged by intermediary servers

2. **No PKCE protection**: The implicit flow doesn't support PKCE, so there's no protection against authorization code interception (there is no code — the token is returned directly).

3. **No refresh tokens**: The implicit flow cannot issue refresh tokens, so the SPA must either use silent renew via hidden iframes (which is increasingly blocked by browsers due to third-party cookie restrictions) or force the user to re-authenticate.

## The Correct Approach: Backend-for-Frontend (BFF) Pattern

The recommended approach for SPAs is the **Backend-for-Frontend (BFF) pattern**, which combines authorization code flow with PKCE and a server-side component.

### How BFF Works

1. The SPA has a **backend host** (e.g., an ASP.NET Core server) that acts as the OAuth client
2. The backend performs the **authorization code flow with PKCE** against IdentityServer
3. After login, **tokens are kept server-side** in the backend's session store — they never reach the browser
4. The SPA communicates with its backend using **session cookies** (standard `HttpOnly`, `Secure`, `SameSite` cookies)
5. The backend **proxies API calls** to downstream APIs, attaching the access token from the server-side session

### Architecture

```
┌─────────┐  cookies  ┌──────────┐  access token  ┌──────┐
│   SPA   │ ────────► │ BFF Host │ ──────────────► │  API │
│ (React) │ ◄──────── │ (ASP.NET)│ ◄────────────── │      │
└─────────┘           └──────────┘                 └──────┘
                           │
                           │ auth code + PKCE
                           ▼
                    ┌──────────────┐
                    │IdentityServer│
                    └──────────────┘
```

### Why BFF Is Better

| Concern | Implicit Flow (SPA) | BFF Pattern |
|---------|-------------------|-------------|
| Token storage | Browser memory/localStorage (vulnerable) | Server-side session (secure) |
| Token exposure | URL fragments, JavaScript accessible | Never reaches the browser |
| Refresh tokens | Not available | Handled server-side |
| Cookie security | N/A | HttpOnly + Secure + SameSite |
| CSRF protection | N/A | Antiforgery headers (x-csrf) |

### What to Use

- Use **authorization code flow with PKCE** (the flow itself)
- Use the **BFF pattern** (the architecture) to keep tokens server-side
- Duende provides the **Duende.BFF** library for ASP.NET Core that implements the BFF pattern with session management, CSRF protection, and API proxying built-in
