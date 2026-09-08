# Authentication Methods in Duende User Management (Passkeys + TOTP)

Duende User Management is **passwordless-first** and supports several authentication methods that can be mixed and matched per user. Your goal — **passkeys as the primary method with TOTP as fallback** — is a fully supported combination, because a single user can have multiple methods enrolled at once.

## Supported Authentication Methods

| Method | What it is |
|--------|-----------|
| **OTP** (default) | One-time codes delivered via **email or SMS** — the default passwordless flow |
| **TOTP** | Time-based one-time passwords from **authenticator apps** (RFC 6238) |
| **Passkeys** | **WebAuthn / FIDO2** — phishing-resistant, hardware/biometric-backed credentials |
| **Passwords** | Traditional username/password (PBKDF2) — opt-in, not recommended as primary |
| **External** | Federated login via OAuth 2.0 / OIDC providers |
| **Recovery codes** | Single-use backup codes, generated during 2FA setup |

## Passkeys (WebAuthn/FIDO2) as Primary

- Passkeys are built on the **WebAuthn / FIDO2** standards.
- They're **phishing-resistant** because the credential is bound to the origin and never leaves the authenticator (platform biometric like Face ID/Windows Hello, or a security key).
- Support is built in; the user's **browser/platform must support WebAuthn** (all modern browsers do).
- Users enroll a passkey from their account/security page, then use it as their day-to-day sign-in.

## TOTP as Fallback

- **TOTP** uses **RFC 6238** time-based codes from standard authenticator apps (Google Authenticator, Microsoft Authenticator, 1Password, Authy, etc.).
- Built in; the user enrolls by scanning a QR code / entering a shared secret, and thereafter enters the rotating 6-digit code.
- It's an ideal fallback for when a passkey isn't available (e.g. a new device without the platform passkey synced).

## Multiple Methods Coexist for the Same User

This is what makes your desired setup work: **a single user can have several authentication methods enrolled simultaneously.** Passkeys and TOTP are not mutually exclusive — a user can register one or more passkeys *and* enroll TOTP, then choose (or be routed to) the appropriate method at sign-in. So you can:

1. Prompt users to enroll a **passkey** as their primary sign-in.
2. Have them also enroll **TOTP** (and generate **recovery codes**) as a fallback.
3. At login, offer passkey first, with TOTP available if the passkey can't be used.

## Note on OTP as the Default

Even though you're leading with passkeys, remember that **email/SMS OTP is the default passwordless flow** in User Management. It's a good additional fallback/bootstrap method (e.g. for initial account access before a passkey is enrolled), and pairs naturally with recovery codes for account recovery.

## Summary

- **Passkeys (WebAuthn/FIDO2)** — supported, phishing-resistant, great as primary.
- **TOTP (RFC 6238 authenticator apps)** — supported, great as fallback.
- **Multiple methods coexist per user**, so passkey-primary + TOTP-fallback is a natural configuration.
- **OTP (email/SMS)** is the default passwordless method; passwords, external login, and recovery codes round out the options.
