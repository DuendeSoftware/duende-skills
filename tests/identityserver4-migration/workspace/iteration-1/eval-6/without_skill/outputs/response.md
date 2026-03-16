# Migrating Signing Keys from IdentityServer4 to Duende IdentityServer

`AddDeveloperSigningCredential()` is a development-only convenience that generates a temporary RSA key stored in a `tempkey.jwk` file. You should **remove it** when migrating to Duende IdentityServer, as it was never intended for production use.

## Replacement Options

For production, you should use a proper signing credential:

1. **X.509 Certificate**: Load a certificate from a file or certificate store:
   ```csharp
   builder.Services.AddIdentityServer()
       .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
   ```

2. **Key from Key Vault**: Use Azure Key Vault or similar HSM-backed key storage for better security.

## Handling Existing Token Validation

Since your clients and APIs are already validating tokens signed with the current developer key, you need to be careful during the transition:

- **Keep the old key available temporarily** as a validation key while you introduce the new signing credential. This way, tokens signed with the old key can still be validated during the overlap period.
- Once all existing tokens have expired (typically after your access token lifetime elapses), you can safely remove the old key.
- Update your APIs to refresh their key sets from the discovery endpoint. Most JWT validation middleware does this automatically by fetching the JWKS from `/.well-known/openid-configuration/jwks`.

## Steps

1. Remove `AddDeveloperSigningCredential()` from your configuration
2. Add a proper signing credential
3. If needed, add the old key as a validation-only key during the transition period
4. Verify that the discovery document reflects the new key
5. Monitor token validation in your APIs during the rollout
