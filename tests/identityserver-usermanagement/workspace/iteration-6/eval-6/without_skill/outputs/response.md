I'm not certain of the full list, so verify against the docs. Duende User Management is generally expected to support passwordless methods: email OTP, passkeys (WebAuthn/FIDO2), TOTP authenticator apps, and possibly passwords and external providers.

Passkeys primary, TOTP as fallback: enable both in configuration, e.g.
```csharp
builder.Services.AddUserManagement(o =>
{
    o.Authentication.Passkeys.Enabled = true;
    o.Authentication.Totp.Enabled = true;
});
```
(property names are illustrative). Design the login UI to offer the passkey prompt first (conditional UI/autofill) with a "Use authenticator app instead" link. Passkeys require HTTPS and a stable relying party ID (your domain). Make users enroll TOTP at registration, as a recovery path, and provide recovery codes.
