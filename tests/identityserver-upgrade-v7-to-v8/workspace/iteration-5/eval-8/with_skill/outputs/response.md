# What changed with v8 licensing, and how to fix both problems

Two independent things are going on: a **license key format change** (causing the `IDX10503` error in your BFF app) and a **runtime enforcement change** (causing the Server-Side Sessions startup throw on the IdentityServer host). Here's each, with the fix.

## Problem 1 — `IDX10503` in the BFF app (license key format)

v8 introduced a **new license key file format**: the v8 key is a **signed JWT that carries a `kid` header**. Older keys are a different format.

- A **v7/earlier-format key still works with v8 core** — running v8 does *not* require buying a new license.
- A **v8-format key does NOT work on v7/earlier runtimes, nor on the BFF Security Framework runtime.** Those runtimes validate the key with Microsoft.IdentityModel and reject it because they can't handle the new signed-JWT format:
  - `IDX10503: Signature validation failed. Token does not have a kid.`
  - That exact error is the tell-tale sign of a **v8-format key dropped into a v7 or BFF runtime**.

**Fix:** put the **v7-format key back into the BFF app** (and any other v7/earlier or BFF runtime). It still validates there, and it still runs v8 core fine. Only production **add-ons** — SAML and Duende User Management — require the new v8-format key; plain v8 core does not.

## Problem 2 — Server-Side Sessions throwing at startup (runtime enforcement change)

v8 changed how it enforces feature entitlements when a **license IS present but lacks the entitlement**. Behavior now splits into two tiers:

| Tier | Behavior when licensed-but-unentitled | Features |
| ---- | -------------------------------------- | -------- |
| A — **throws at startup** | Startup validation fails | **Server-Side Sessions, Automatic Key Management, SAML** (IdP + SP) |
| B — **logs a warning** | Rate-limited warning (~once/5 min) | DPoP, Resource Isolation, CIBA, Dynamic Identity Providers, Financial-grade/Conformance, User Management |

That's why it used to "just log a warning" and now **throws**: Server-Side Sessions moved into the throw tier. In v7 and earlier, unlicensed features were instead **silently disabled** — v8 no longer disables; it logs or throws per the tiers above.

Note: if **no license is configured at all** (pure local dev), Tier-A features **downgrade to logging** instead of throwing.

**Fix:** ensure your license actually includes the **Server-Side Sessions** entitlement (it's part of the Business/Enterprise-level plans). If you're entitled, make sure the correct key is being loaded (v8 also reads it automatically from configuration at `Duende:IdentityServer:LicenseKey` or `Duende:LicenseKey`). If you genuinely aren't entitled, either obtain the entitlement or stop using Server-Side Sessions.

## Recommendation — surface entitlement gaps early

Because Tier-A features now throw, run your **lower/non-production environments with the production license key**. That way a missing entitlement (like Server-Side Sessions) fails fast in dev/staging instead of taking down your production startup.

## Summary

- The `IDX10503` is a **key-format** mismatch: a v8 signed-JWT key in a v7/BFF runtime. Use the **v7-format key** there — no new purchase is needed to run v8 core.
- The startup throw is the **new enforcement tier**: Server-Side Sessions (with Automatic Key Management and SAML) now throw when licensed-but-unentitled, while other features only warn.
- Use the **production key in lower environments** to catch these gaps before production.
