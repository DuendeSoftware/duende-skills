# Systematic Debugging of `invalid_client` (and Token Endpoint Failures)

`invalid_client` specifically means the token endpoint could not authenticate your client (`web.app`) — the client identity or its credential didn't validate. Work the checklist top to bottom; the same discipline applies to any token-endpoint failure.

## 1. Verify the discovery document

Before anything else, confirm you're even talking to the right server correctly.

- Hit `https://identity.example.com/.well-known/openid-configuration` in a browser or `curl`.
- Is it **reachable** and does it return **valid JSON**?
- Does `token_endpoint` point where you expect? You should be posting to `disco.TokenEndpoint`, not a hand-built URL.

If discovery is broken or you're hardcoding the wrong endpoint, every request fails before client auth is even considered.

## 2. Client ID exact match

- Does the `client_id` in the request **exactly** match the registered client on the server (`web.app`)? Case-sensitive, no stray whitespace, no environment mix-up (staging client id sent to prod server).

## 3. Client secret — check for encoding issues

This is the most common cause of `invalid_client`.

- Confirm the secret value is exactly `correct-secret` with **no trailing newline or whitespace** (very common when read from a file or env var).
- **Duende stores client secrets as a SHA256 hash by default.** If the client was registered with `new Secret("correct-secret".Sha256())`, you must send the **plaintext** `correct-secret` — the server hashes what you send and compares. A frequent mistake is registering the *already-hashed* value, or sending the hash instead of the plaintext, causing a **Sha256-hash-vs-plaintext mismatch**.
- Check the **authentication method**: are you sending the secret the way the client is configured (`client_secret_basic` = HTTP Basic Authorization header, vs `client_secret_post` = form body)? A mismatch here yields `invalid_client`.

## 4. Grant type and scopes are allowed

- Is the grant type you're using listed in the client's **`AllowedGrantTypes`**? (e.g. `authorization_code`, `client_credentials`.) A grant the client isn't allowed to use is rejected.
- Are all requested scopes registered in the client's **`AllowedScopes`** (and do the API/identity resources exist)? An unregistered scope fails the request.

## 5. Redirect URI exact match (for code flow)

For the authorization code grant, the `redirect_uri` at the token endpoint must **exactly** match one registered in `RedirectUris` and the one used in the authorize request:

- Exact **scheme** (`https` vs `http`)
- Exact **host**
- Exact **port**
- Exact **path**
- **Trailing slash** matters — `/signin-oidc` ≠ `/signin-oidc/`

## 6. PKCE

- If the client requires PKCE (Duende requires it by default for interactive clients), is the token request sending the `code_verifier` that matches the earlier `code_challenge`? A missing/mismatched verifier fails the exchange.

## 7. Clock skew

- Is the client/server system time correct? Token and assertion validation allow limited skew (default ~5 min). A badly wrong clock invalidates timestamps.

## 8. HTTPS

- Are the authorize redirect and token calls over **HTTPS**? Mixed content and non-TLS calls to a TLS-required server cause silent or hard failures.

## 9. CORS (browser-originated calls)

- If you're calling the token endpoint directly from a browser, is the origin in the client's **`AllowedCorsOrigins`**? Otherwise the browser blocks the response.

## How to get the real reason fast

Don't guess — read the server logs. Duende IdentityServer logs the concrete rejection reason (e.g. "invalid client secret", "client secret is missing", "unknown client") at the token endpoint. That log line usually tells you which of the above checks failed in one step. Also inspect the raw HTTP response body: the `error` (`invalid_client`) plus any `error_description` narrows it down.

For your case (`invalid_client` with `web.app` / `correct-secret`), start at **step 3** — it's almost always a secret encoding/hashing mismatch or the wrong client authentication method.
