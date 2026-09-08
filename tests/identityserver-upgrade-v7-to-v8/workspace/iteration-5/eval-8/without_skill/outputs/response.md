# Diagnosing the two v8 issues

I don't have Duende's v8 licensing internals memorized, so I'll reason from the error and general JWT/licensing knowledge. Please confirm the specifics with Duende's official v8 upgrade/licensing docs — licensing behavior is product-specific and I don't want to overstate what I can't verify.

## The `IDX10503` error in the BFF app

`IDX10503: Signature validation failed. Token does not have a kid.` is a **Microsoft.IdentityModel** error. It means a JWT was being signature-validated and the code couldn't select a signing key because the token has no `kid` (key ID) header to match against the configured keys.

Duende license keys are themselves signed tokens, so this strongly suggests a **mismatch between the license key and the runtime that's trying to validate it**. The most likely explanation is that the license-key format or its validation changed between the version that issued your key and the BFF runtime you dropped it into.

What I'd check:
- Whether the license key you pasted into the BFF app is the correct/current key for the version of the BFF/Security Framework packages you're running.
- Whether the BFF runtime expects a different license-key format than the IdentityServer host does. If v8 changed the key format, an older runtime (or a different product like the BFF framework) may not be able to validate the newer key, or vice-versa.
- That you copied the whole key value without truncation.

Since I can't confirm the exact format rules, I'd contact Duende or check the licensing docs to get the correct key for each runtime. You may need a license key that the BFF runtime can validate.

## The Server-Side Sessions startup exception

Previously this only logged a warning; now it throws at startup. That points to **v8 tightening its license/feature enforcement**. Where older versions tolerated (or silently disabled) an unlicensed feature, v8 appears to fail fast when a licensed feature like Server-Side Sessions is enabled but not covered by your license.

What I'd do:
- Verify your license actually includes the Server-Side Sessions feature/edition. If it doesn't, either add it to your license or disable Server-Side Sessions.
- Make sure the license key is being loaded correctly at startup (right configuration key, not expired).
- Review the v8 release notes for the list of features that now enforce licensing strictly, so you're not surprised by another one.

## General advice

- Keep the correct license key per environment and per runtime, and confirm with Duende which key/format each of your runtimes (IdentityServer host vs. BFF) expects for v8.
- Treat the startup throw as intentional stricter enforcement and make sure your license entitlements match the features you've enabled.

I've flagged where I'm inferring — the exact license-key format change and the precise list of features that throw vs. warn should be confirmed in Duende's v8 documentation.
