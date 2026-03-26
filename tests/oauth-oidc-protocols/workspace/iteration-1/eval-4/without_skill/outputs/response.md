# SPA Security: Implicit Flow vs Modern Approaches

## Your Colleague is Right

The implicit flow is considered insecure and has been deprecated. The main issues:

- Tokens are exposed in URL fragments, making them visible in browser history
- No support for PKCE
- No refresh tokens
- Vulnerable to token leakage through referrer headers

## Better Approach

Instead of implicit flow, use **authorization code flow with PKCE**. For SPAs specifically, consider the **Backend-for-Frontend (BFF) pattern**:

1. The SPA has a backend server component
2. The backend performs the OAuth flow (authorization code + PKCE)
3. Tokens stay on the server side
4. The SPA communicates with its backend using cookies

This keeps tokens out of the browser entirely, which is much more secure than handling tokens in JavaScript.

## Alternative

If you can't implement a BFF, you can use authorization code + PKCE directly from the SPA, but tokens will be in browser memory which is still risky.
