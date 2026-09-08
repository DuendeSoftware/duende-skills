# Is Implicit Flow Insecure for a SPA?

Your colleague is correct — using the **implicit flow** to get an access token in the browser is considered insecure and is no longer recommended.

## Why implicit flow is a problem

With implicit flow, the authorization server returns the access token directly in the **URL fragment** of the redirect:

```
https://yourapp/callback#access_token=eyJhbGciOi...&expires_in=3600
```

That has several downsides:

- The token appears in the URL, so it can end up in browser history, server logs, or be leaked through the `Referer` header or browser extensions.
- There is no PKCE or client authentication, so there's nothing binding the token to the legitimate client.
- Implicit flow doesn't support refresh tokens well, leading to awkward hidden-iframe renewal tricks.

Because of these issues, the OAuth working group deprecated implicit flow in the current security best practices.

## What to do instead

Use the **authorization code flow with PKCE** (Proof Key for Code Exchange). This is now the recommended flow for single-page applications:

1. The SPA generates a `code_verifier` and a `code_challenge` (SHA256 of the verifier).
2. It redirects the user to the authorization endpoint with `response_type=code` and the `code_challenge`.
3. After login, the SPA receives an authorization code.
4. It exchanges the code plus the original `code_verifier` at the token endpoint to get tokens.

Because PKCE proves the client that started the flow is the same one exchanging the code, an intercepted code can't be used by an attacker. Most SPA libraries (oidc-client-ts, MSAL, etc.) implement this for you.

## Even more secure: keep tokens off the browser

For higher security you can avoid storing tokens in the browser at all. A common approach is to introduce a lightweight backend that handles the OAuth flow and holds the tokens, exposing only cookie-authenticated endpoints to the SPA. This keeps access and refresh tokens out of JavaScript, where they'd otherwise be vulnerable to XSS. If you do keep tokens in the SPA, prefer in-memory storage over `localStorage`.

## Summary

- Stop using implicit flow — it's deprecated and exposes tokens in the URL.
- Switch to authorization code flow with PKCE.
- Optionally move token handling to a backend so tokens never live in the browser.
