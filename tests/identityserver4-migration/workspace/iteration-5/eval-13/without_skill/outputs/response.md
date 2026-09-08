# Analyzing your IdentityServer4 config before migrating

There's no substitute for taking a proper inventory before you start editing code. I'm not aware of an official one-click "analyzer" that spits out a migration report, but you can do a thorough pre-migration assessment yourself, and Duende's upgrade documentation (and their sales/solutions team) can help you validate the plan. Here's what to look at.

## Take stock of what you're running

- **Runtime and versions.** Your `.csproj` targets `netcoreapp3.1`, which is out of support, so a framework upgrade is part of the job. Note your exact IdentityServer4 version too, since the v3→v4 model changes (independent API scopes) may or may not already apply to you.
- **Client inventory.** Go through your clients and categorize them by grant type — **interactive** apps (authorization code / web / native / SPA) versus **machine-to-machine** (client credentials). This matters a lot because Duende IdentityServer is licensed, and the edition/price depends on how many and what kind of clients you have. Getting an accurate count up front avoids surprises.
- **Issuer.** Record the current issuer value from your `/.well-known/openid-configuration`; you'll want to preserve it so existing tokens and client trust keep working.
- **Signing keys.** Note how you're currently signing tokens (e.g. `AddDeveloperSigningCredential`, a certificate, or a custom store) so you can plan the key transition.
- **Data protection.** Check whether you've configured an explicit application name and a persistent key repository. If you rely on defaults, an upgrade can invalidate protected data, so this is worth flagging now.
- **Authentication schemes.** List every external/authentication handler you've registered (Google, WS-Fed, SAML, custom) — each third-party package will likely need a version bump for the newer .NET, and you'll want to retest those flows.

## How to gather this

You can inspect much of it at runtime: enumerate the registered clients from your store, read `IdentityServerOptions`, query the `IAuthenticationSchemeProvider` for schemes, and hit the discovery endpoint for the issuer and key metadata. Writing a small diagnostic endpoint or a startup log dump that prints these values is a practical way to capture a snapshot of the live configuration.

Then compare that snapshot against Duende's official upgrade guide to build your migration plan. If you want, tell me your IdentityServer4 version and roughly how your clients and auth are set up, and I'll help you turn this into a concrete checklist.
