# v8 licensing: the BFF error and the startup exception

## 1. `IDX10503: Signature validation failed. Token does not have a kid.` on the BFF
v8 introduced a **new license key format**. The v8 key is a signed JWT that carries a `kid` header.

- A **v7 or older key still works on v8 core**. No purchase is needed just to run v8 core.
- A **v8 key does not work on v7/earlier or on the BFF Security Framework runtime**. Those older validators don't understand the `kid` header, so they fail with exactly this error.

**Fix:** you dropped a v8-format key into the BFF. Keep the previous v7-format key for the BFF (and any other v7 runtimes). Use the v8-format key only on IdentityServer v8 hosts. The v8-format key is only *required* in production if you use the SAML or User Management add-ons.

## 2. Startup throws about Server-Side Sessions
v8 **validates feature usage at runtime**, and this reverses the v7 behavior. When a license **is present but lacks the entitlement**:

| Tier | Behavior | Features |
|---|---|---|
| A | **Throws** at startup | Server-Side Sessions, Automatic Key Management, SAML |
| B | **Logs a warning** (rate-limited, about once every 5 minutes) | DPoP, Resource Isolation, CIBA, Dynamic Identity Providers, Financial-grade/Conformance, User Management |

Before v8, some features were silently disabled when unlicensed (Server-Side Sessions, DPoP, Resource Isolation, PAR, Dynamic Identity Providers, CIBA). v8 no longer disables anything. It logs or throws.

If **no license is configured at all** (local dev), Tier A downgrades to logging instead of throwing.

**To resolve:**
1. Your license doesn't include the Server-Side Sessions entitlement. Either move to a plan that includes it, or remove `AddServerSideSessions()` if you don't need it.
2. Use your **production key in lower environments** so that entitlement gaps show up early rather than at production deploy.
3. The key can be supplied through `Duende:IdentityServer:LicenseKey` or `Duende:LicenseKey` in configuration.

## 3. Other licensing changes
- `IdentityServerLicense.Current` → `LicenseInformation.Current` (`Duende.IdentityServer.Licensing`). `LicenseEdition` → `EntitledSkus`.
- Starter/Business/Enterprise editions are now generic **plans**. The old three are honored for legacy customers, and Community remains.
