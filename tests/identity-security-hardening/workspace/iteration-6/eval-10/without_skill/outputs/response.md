# Rotating static signing keys safely

The key idea: **publish the new key before you sign with it, and keep the old key published until all tokens signed by it have expired.** Clients and APIs cache the JWKS, so a sudden swap breaks validation.

## Sequence
1. **Create the new key** (e.g. new RSA/EC key or certificate) and store it securely.
2. **Add it as a validation key only (announce)**: keep the old key as the signing credential, and add the new one so it appears in discovery (`jwks_uri`).
   ```csharp
   builder.Services.AddIdentityServer()
       .AddSigningCredential(oldKey, "RS256")            // still signing
       .AddValidationKey(newKey, "RS256");               // published, not signing
   ```
3. **Wait for propagation**: at least the longest JWKS cache duration of your APIs/clients (often 24h; check each, ASP.NET JWT bearer refreshes automatically on unknown `kid` in some cases but don't rely on it). Deploy to all nodes.
4. **Switch signing to the new key**, and keep the old key as a validation key:
   ```csharp
       .AddSigningCredential(newKey, "RS256")
       .AddValidationKey(oldKey, "RS256");
   ```
5. **Retain the old key** until every token it signed has expired: at least max access token lifetime (and id token / logout token / JWT-based artifacts lifetimes), plus clock skew and JWKS cache time.
6. **Remove the old key** from config.

## The overlap requirement
Two overlaps are needed:
- **Before signing**: the new public key must be in discovery for ≥ the JWKS cache TTL, or APIs will see an unknown `kid` and reject tokens.
- **After signing**: the old public key stays published ≥ the longest token lifetime + cache + skew, so previously issued tokens still validate.

Each token contains a `kid`, so multiple keys coexist without ambiguity. In a load-balanced setup, all nodes must have the same key configuration at each step. Consider moving to automatic key management to avoid doing this manually.
