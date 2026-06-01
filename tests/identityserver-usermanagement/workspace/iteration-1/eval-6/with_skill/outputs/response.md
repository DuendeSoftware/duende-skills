# Authentication Methods in Duende User Management

Duende User Management supports multiple authentication methods that can coexist for the same user:

## Supported Methods

| Method | Description | Notes |
|--------|-------------|-------|
| **OTP** (default) | One-time codes delivered via email or SMS | Default passwordless flow; requires `IOtpDispatcher` |
| **TOTP** | Time-based one-time passwords (RFC 6238) | Works with authenticator apps (Google Authenticator, Authy, etc.); user enrollment required |
| **Passkeys** | WebAuthn/FIDO2 phishing-resistant credentials | Hardware keys or platform authenticators (Touch ID, Windows Hello); browser support required |
| **Passwords** | Traditional username/password (PBKDF2) | Opt-in, not recommended as primary method |
| **External** | OAuth 2.0 / OIDC federated login | Uses standard ASP.NET Core authentication handlers |
| **Recovery codes** | Single-use backup codes | Auto-generated during 2FA setup |

## Passkeys as Primary with TOTP Fallback

This is an excellent combination. Here's how it works:

1. **Passkeys (primary)** — WebAuthn/FIDO2 provides phishing-resistant authentication. Users register a passkey (hardware security key, Touch ID, Windows Hello, etc.) and authenticate with a simple gesture. No codes to type, no phishing risk.

2. **TOTP (fallback)** — RFC 6238 authenticator apps generate time-based codes. Users enroll by scanning a QR code in their authenticator app. This serves as a fallback when the passkey isn't available (e.g., new device, lost hardware key).

Both methods can be registered simultaneously for the same user. During login, the user can choose which method to use.

## Default Flow

**OTP via email/SMS is the default passwordless flow.** When a user first authenticates, they receive a one-time code. This is the simplest setup and requires only an `IOtpDispatcher` implementation. Users can then enroll in additional methods (passkeys, TOTP) for stronger security.

## Configuration

Multiple methods are enabled by default in User Management. Users self-enroll in passkeys and TOTP through the account management UI. No additional configuration is needed beyond ensuring the base OTP dispatcher is registered for initial authentication.
