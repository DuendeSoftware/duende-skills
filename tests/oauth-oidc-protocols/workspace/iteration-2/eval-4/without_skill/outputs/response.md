# SPA Security: Implicit Flow vs Better Alternatives

## Yes, Your Colleague is Right

The implicit flow is considered insecure and deprecated. Here's why:

### Problems with Implicit Flow

- **Tokens in URL fragments**: The access token is returned in the URL fragment (`#access_token=...`), which can be leaked through browser history, referrer headers, and browser extensions
- **No refresh tokens**: Implicit flow doesn't support refresh tokens, so you have to use silent renewal with iframes, which is increasingly unreliable due to third-party cookie blocking
- **Short-lived tokens only**: Without refresh tokens, you're limited to short-lived access tokens

## What to Do Instead

### Use Authorization Code Flow with PKCE

Instead of implicit flow, use the authorization code flow with PKCE. This is the current best practice for all client types including SPAs.

### Consider a Backend-for-Frontend (BFF) Pattern

For SPAs, the recommended architecture is to have a lightweight backend that handles the OAuth flow:

1. Your React app communicates with a backend server using **session cookies**
2. The backend server performs the authorization code + PKCE flow
3. **Tokens are stored server-side** on the backend, never exposed to the browser
4. The backend proxies API calls, attaching the access token

This way:
- No tokens are ever accessible to JavaScript in the browser
- You get standard cookie-based security (HttpOnly, Secure, SameSite)
- Refresh tokens are handled server-side automatically

### Architecture

```
Browser (React) <--cookies--> BFF Backend <--access token--> API
                                   |
                                   | auth code + PKCE
                                   v
                            Identity Provider
```

This pattern is much more secure than having the SPA directly obtain and manage tokens.
