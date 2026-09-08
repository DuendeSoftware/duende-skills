# Is Implicit Flow Insecure for a React SPA? Yes.

Your colleague is right. The **implicit flow is deprecated** and you should not use it. Here's why, and what to do instead.

## Why implicit flow is insecure

The implicit flow (`response_type=token` / `id_token token`) returns the access token **directly in the URL fragment** of the redirect back to your app:

```
https://myapp/callback#access_token=eyJ...&token_type=Bearer&expires_in=3600
```

That design has several problems:

- **Tokens are exposed in the URL fragment** — they land in browser history, can leak via the `Referer` header, browser extensions, logs, and analytics scripts.
- **No PKCE / no client authentication** — there's no proof-of-possession, so an intercepted token is immediately usable.
- **No refresh tokens** — implicit flow can't safely issue refresh tokens, forcing fragile silent-renew-via-iframe workarounds.

For these reasons the OAuth 2.0 Security Best Current Practice and the "OAuth 2.0 for Browser-Based Apps" guidance **deprecate implicit flow** entirely.

## What to use instead: authorization code + PKCE, via a BFF

The replacement for implicit flow is the **authorization code flow with PKCE**. PKCE protects the code exchange so there's no client secret in the browser and an intercepted code is useless.

But the more important architectural point for a React SPA is *where the tokens live*. The recommended approach today is the **Backend-for-Frontend (BFF) pattern**:

- You put a **server-side component** (the BFF — for .NET, `Duende.BFF`) next to your SPA. The BFF is a confidential OAuth client.
- The BFF performs the **authorization code + PKCE** flow and receives the ID token, access token, and refresh token.
- **Tokens are stored server-side** in the BFF's session — they never reach JavaScript.
- The SPA authenticates to its own BFF with a **secure, HttpOnly, SameSite session cookie**. The browser never sees or handles an access token.
- When the SPA needs to call an API, it calls its BFF (cookie-authenticated); the BFF attaches the real access token and proxies the request.

```
Browser (React SPA)  --HttpOnly session cookie-->  BFF (server)  --access token-->  API
```

### Why BFF is better than doing PKCE in the SPA itself

You *can* run authorization code + PKCE entirely in the browser (many libraries do), but the access/refresh tokens then live in JavaScript-reachable storage (memory, `localStorage`, `sessionStorage`), where they are exposed to XSS. The BFF pattern removes tokens from the browser entirely, which is why it is the current recommendation for browser-based apps handling anything sensitive. XSS on a BFF-backed SPA can still ride the session, but the long-lived tokens themselves cannot be exfiltrated.

## Summary

| | Implicit flow | BFF (auth code + PKCE, server-side) |
|---|---|---|
| Token location | URL fragment → browser | Server-side session |
| Browser holds tokens? | Yes | No — only a cookie |
| PKCE protection | No | Yes |
| Refresh tokens | No (iframe hacks) | Yes, safely server-side |
| Status | Deprecated | Recommended |

**Bottom line:** drop implicit flow. Adopt the BFF pattern using authorization code + PKCE, keep all tokens server-side, and have your React app talk to its backend using a session cookie. In the .NET world, `Duende.BFF` implements exactly this.
