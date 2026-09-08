# Debugging `invalid_client` at the Token Endpoint

`invalid_client` means the authorization server couldn't authenticate your client. It's almost always about the client identity or its credentials, but let's work through a systematic checklist so you don't miss anything.

## 1. Confirm you're hitting the right endpoint

- Load the discovery document at `https://identity.example.com/.well-known/openid-configuration` and make sure it's reachable and returns valid JSON.
- Verify the `token_endpoint` value and that your request is actually going there (not an old or wrong URL).

## 2. Check the client ID

- Make sure the `client_id` you send (`web.app`) exactly matches what's registered on the server — no typos, no leading/trailing spaces, and not a client from a different environment (dev vs prod).

## 3. Check the client secret

- Confirm the secret matches exactly. Watch out for:
  - Trailing newlines or whitespace when the secret is read from a file or environment variable.
  - URL-encoding problems if the secret contains special characters.
  - The secret being sent in the wrong place — some servers expect it in the HTTP Basic `Authorization` header (`client_secret_basic`), others in the POST body (`client_secret_post`). Sending it the wrong way causes `invalid_client`.

## 4. Check the client authentication method

- The client's configured authentication method must match how you're sending credentials. Confirm whether the client is public (no secret) or confidential (secret required). A public client sending a secret, or a confidential client omitting it, both fail.

## 5. Check the redirect URI (for authorization code flow)

- If you're doing the authorization code flow, the `redirect_uri` must match the registered one **exactly**: scheme, host, port, path, and even a trailing slash. `https://app/callback` and `https://app/callback/` are different.

## 6. Check grant type and scopes

- Make sure the grant type you're requesting is one the client is allowed to use.
- Make sure the scopes you request are registered and allowed for the client. (Though a bad scope usually returns `invalid_scope`, not `invalid_client`.)

## 7. Other things to check

- **Clock skew** — if the client uses a signed JWT assertion for authentication, a wrong system clock can invalidate it.
- **HTTPS** — make sure requests go over HTTPS.
- **Read the server response and logs** — the `error_description` field and the server's logs usually state the exact reason (unknown client, invalid secret, etc.), which is the fastest way to pinpoint it.

## For your case

Since the client ID and secret look correct on the surface, focus on step 3 and step 4: how the secret is being transmitted (header vs body) and whether there's hidden whitespace/encoding in the secret value. Then check the server logs for the precise rejection reason.
