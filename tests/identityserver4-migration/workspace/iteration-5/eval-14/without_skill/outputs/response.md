# Watch out for the issuer when you change hosting

You've flagged the exact risk yourself: your IdentityServer4 doesn't set an explicit `IssuerUri`, so it derives the issuer from the request URL. When you move from IIS on Windows to Kestrel behind nginx on Linux, the URL the app "sees" can change (scheme, host, port, or path), and that would change your issuer.

## Why this is a big deal

The issuer is emitted as the **`iss` claim** in every token you issue and as the `issuer` field in `/.well-known/openid-configuration`. Clients and APIs treat it as part of their trust anchor:

- Resource APIs validate that `iss` on an incoming token matches the issuer they're configured for. If it changes, **previously issued tokens fail validation**.
- OIDC clients validate the issuer during discovery/metadata handling, so a changed issuer **breaks the trust relationship** and logins/token validation start failing.

So the golden rule is: **the issuer must stay exactly the same before and after the migration.**

## How to keep it stable

1. **Find the current value.** Hit your existing server's discovery endpoint:
   ```
   https://your-old-host/.well-known/openid-configuration
   ```
   and copy the `issuer` value verbatim.

2. **Set it explicitly in the new deployment** instead of leaving it inferred:
   ```csharp
   builder.Services.AddIdentityServer(options =>
   {
       options.IssuerUri = "https://your-old-host"; // must match the old issuer exactly
   });
   ```
   Pinning it means it no longer depends on how nginx forwards the request.

3. **Fix the proxy headers too.** Behind nginx, enable forwarded headers (`UseForwardedHeaders`, forwarding `X-Forwarded-Proto` and `X-Forwarded-Host`) so the app generates correct HTTPS URLs for endpoints and redirects. Otherwise the discovery document can show `http://` or an internal hostname even if the issuer itself is pinned.

4. **Confirm after go-live.** Diff the new discovery document's `issuer` against the old one — they should be character-for-character identical.

Get the issuer right and the hosting change is mostly transparent to your clients; get it wrong and every relying party breaks at once.
