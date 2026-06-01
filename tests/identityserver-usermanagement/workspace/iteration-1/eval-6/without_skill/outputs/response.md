# Authentication Methods with IdentityServer

Duende IdentityServer supports various authentication methods depending on how you configure your user store.

## Common Authentication Methods

1. **Username/Password** — Traditional credential-based login using ASP.NET Core Identity.

2. **Multi-factor Authentication (MFA)** — ASP.NET Identity supports TOTP-based 2FA with authenticator apps.

3. **External Providers** — OAuth 2.0/OIDC federation with Google, Microsoft, etc. using ASP.NET Core authentication handlers.

4. **FIDO2/WebAuthn** — Passkey support can be added through third-party libraries like `Fido2NetLib`.

## Setting Up Passkeys + TOTP

For passkeys, you'd typically use a library like FIDO2.NET:

```bash
dotnet add package Fido2.AspNet
```

For TOTP, ASP.NET Identity has built-in support:

```csharp
builder.Services.AddIdentity<IdentityUser, IdentityRole>(options =>
{
    options.Tokens.AuthenticatorTokenProvider = TokenOptions.DefaultAuthenticatorProvider;
})
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();
```

## Combining Methods

You can offer multiple methods by:
- Implementing passkey registration/verification endpoints using FIDO2.NET
- Using the built-in TOTP support in ASP.NET Identity as a fallback
- Allowing users to choose their preferred method during login

## Notes

- Passkeys are the most phishing-resistant option available.
- TOTP works well as a fallback since it only requires an authenticator app.
- Consider offering recovery codes as a last-resort backup.
