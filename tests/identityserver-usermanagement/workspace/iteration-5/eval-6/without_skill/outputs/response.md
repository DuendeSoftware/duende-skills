# Authentication Methods: Passkeys as Primary with TOTP Fallback

I don't have product-specific documentation for Duende's user-management offering in front of me, so I'll describe the authentication methods a modern .NET identity stack of this kind typically supports, and how to set up **passkeys as primary with TOTP as a fallback** — which is a well-established, standards-based pattern.

## Commonly Supported Methods

- **Passkeys (WebAuthn / FIDO2)** — public-key credentials bound to the site origin; unlocked by a platform biometric (Face ID, Touch ID, Windows Hello) or a roaming security key. Phishing-resistant by design.
- **TOTP (authenticator apps)** — RFC 6238 time-based 6-digit codes from apps like Google Authenticator, Microsoft Authenticator, Authy, or 1Password.
- **Email / SMS one-time codes (OTP)** — a code sent to a verified email or phone number.
- **Passwords** — traditional credential, often combined with one of the above as a second factor.
- **External / social login** — federated sign-in via OIDC/OAuth providers (Google, Microsoft, etc.).
- **Recovery / backup codes** — single-use codes issued when a user sets up MFA, for when they lose their device.

## Passkeys as the Primary Method

Passkeys use the **WebAuthn** browser API and the **FIDO2/CTAP** standards. Key points:

- The private key never leaves the authenticator; the server stores only a public key and credential ID.
- They're **phishing-resistant** because the credential is scoped to your domain.
- Requires a modern browser/OS (all current major platforms support WebAuthn) and a per-user registration ("enroll a passkey") step.

At sign-in you'd offer the passkey ceremony first.

## TOTP as the Fallback

- The user enrolls once by scanning a QR code that encodes a shared secret.
- Thereafter they enter the rotating 6-digit code.
- It's a solid fallback when a passkey isn't available on the current device.

## Combining Them

Because these are independent factors/credentials, a user can enroll **both a passkey and TOTP at the same time** — they aren't mutually exclusive. A typical UX:

1. On account setup, prompt to register a **passkey** as the primary method.
2. Prompt to also enroll **TOTP** and download **recovery codes** as fallbacks.
3. At login, attempt the passkey first; if unavailable, fall back to the TOTP prompt.

## Recommendation

Lead with passkeys for the best security and UX, keep TOTP (plus recovery codes) as the backup, and verify the exact method names and registration APIs in Duende's user-management documentation, since the extension methods and enrollment endpoints will be product-specific.
