## Supported methods
| Method | Notes |
|---|---|
| **OTP** (default) | Email/SMS codes; needs an `IOtpDispatcher` |
| **TOTP** | Authenticator apps (RFC 6238), built-in, users enroll |
| **Passkeys** | WebAuthn/FIDO2, built-in, phishing-resistant; can also be a second factor |
| **Passwords** | PBKDF2, opt-in, not recommended as primary |
| **External** | OAuth 2.0/OIDC federated login via standard ASP.NET Core handlers |
| **Recovery codes** | Single-use backup codes, generated during 2FA setup |

User Management is passwordless-first.

## Passkeys primary, TOTP fallback
`AddUserManagement(...)` registers the passkey services automatically (ES/RS/PS algorithms, WebAuthn ceremonies, credential storage, challenge management); TOTP is built-in too. So there is little configuration:

```csharp
builder.Services.AddIdentityServer(o =>
{
    o.UserInteraction.LoginUrl = "/Account/Login";
    o.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddStorage(s => s.AddPostgreSql())
    .AddUserManagement(options => options.Authentication(a =>
        a.UseSmtpOtpDispatcher(smtp => builder.Configuration.GetSection("Smtp").Bind(smtp)))); // OTP still used for sign-up/verification

var app = builder.Build();
app.UseIdentityServer();
app.MapUserManagement();   // required: exposes passkey endpoints incl. /passkeys/js
app.MapRazorPages();
```

"Primary vs fallback" is a **UI ordering decision** in your login page: first offer passkey sign-in (via `/passkeys/js`), then a "use authenticator app" option for TOTP. Ensure users enroll TOTP (and get recovery codes) so they have a fallback. Passkeys need browser support and HTTPS with a stable domain. `ChallengeSize` defaults to 32 bytes (min 16); stored `Transports` are client hints, not verified. Remember `MigrateAsync()` for the storage schema.
