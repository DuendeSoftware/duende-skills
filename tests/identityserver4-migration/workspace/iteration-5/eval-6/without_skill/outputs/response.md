# Handling signing keys when migrating away from `AddDeveloperSigningCredential()`

`AddDeveloperSigningCredential()` creates a throwaway development key (it writes a `tempkey.jwk`/`tempkey.rsa` file next to the app). It's fine for local work but should not be used in production, so you'll want to replace it as part of the move to Duende.

## Remove the developer credential

Drop the call:

```csharp
services.AddIdentityServer()
    .AddDeveloperSigningCredential();   // remove this
```

## Replace it with proper key handling

Duende IdentityServer ships with **automatic key management**, which generates and rotates signing keys for you and stores them in your operational store. For most people this is the recommended replacement — you simply stop configuring a signing credential and let Duende manage keys. Alternatively, if you want an explicit, fixed key you can provide your own certificate:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
```

## Not breaking tokens that are already in circulation

This is the part to be careful with. Clients and resource APIs validate a token's signature using the keys published at your JWKS endpoint (`jwks_uri` in the discovery document). If you swap keys, you need those relying parties to trust the new key.

- **Rolling transition:** the safest approach is to keep your **current key available for validation** while introducing the new one, so tokens signed with the old key continue to verify during the overlap window. You publish both keys in the JWKS, issue new tokens with the new key, and only retire the old key once no valid tokens signed by it remain (i.e., after the old tokens' lifetime has elapsed). This is exactly how key rotation is meant to work.
- **Coordinated restart:** if you're able to restart your client apps and APIs, they will re-fetch the discovery document and JWKS and **pick up the new signing key automatically**, so a straightforward cutover is possible when you control all the relying parties.

In short: remove `AddDeveloperSigningCredential()`, adopt Duende's automatic key management, and either do a rolling transition that keeps the old key valid for a while, or coordinate a restart so everyone reloads the new key from discovery.
