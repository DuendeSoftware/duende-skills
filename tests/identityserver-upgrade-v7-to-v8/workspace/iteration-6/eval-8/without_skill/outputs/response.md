# v8 licensing: the BFF and server-side sessions errors

I'm not sure of the exact v8 licensing changes, so treat this as a best-effort explanation.

## BFF: `IDX10503: Signature validation failed. Token does not have a kid.`
That is a `Microsoft.IdentityModel` error. It means a JWT was being validated but had no `kid` header. The usual cause is that the license key format changed. Newer Duende license keys appear to be signed JWTs, and a key issued for v7 or an older format isn't valid for the new validator. A key issued for IdentityServer may also not cover the BFF product. **Fix:** get a new v8-format key from your Duende account for the product and edition you have, and set it on the BFF through `LicenseKey` or the license file. Don't reuse the old key.

## IdentityServer host: Server-Side Sessions now throws
v7 only logged a warning when you used a feature not covered by your license edition. v8 appears to enforce the license strictly. Server-side sessions require the Business edition or higher, so startup now fails.

**Options:**
1. Upgrade your license to an edition that includes server-side sessions.
2. Remove `.AddServerSideSessions()` and use cookie-based sessions if you don't need the feature.
3. Check that the key is the new format and matches the edition you bought.

Confirm the details with Duende support and the upgrade guide.
