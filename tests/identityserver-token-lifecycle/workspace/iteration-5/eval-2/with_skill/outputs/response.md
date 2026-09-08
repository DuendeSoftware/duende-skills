# Switching `web_app` to Reference Access Tokens

You want the ability to revoke access tokens on demand. That is precisely the use case for **reference tokens**.

## Why reference tokens (and not JWTs)

A **JWT access token is stateless** — it is self-contained and validated by the API purely by checking the signature against IdentityServer's public keys. Nothing about it is stored server-side, so there is **no revocation state to flip**. A JWT simply remains valid until its `exp`. The revocation endpoint (`/connect/revocation`, RFC 7009) **only operates on reference access tokens and refresh tokens** — the tokens that are actually persisted in the operational (persisted grant) store. So if you need to invalidate an access token immediately (logout, compromise, entitlement change), you must issue reference tokens.

A **reference token** is just an opaque handle pointing at token data in the persisted grant store. The API validates it by calling the **introspection endpoint** (`/connect/introspect`), and you revoke it immediately by deleting the stored grant.

## Changes required

1. Set `AccessTokenType = AccessTokenType.Reference` on `web_app`.
2. Set `AccessTokenLifetime = 900` (15 minutes).
3. Give the `ApiResource` an `ApiSecrets` entry — introspection is an authenticated call, so the API authenticates with that secret.

### `web_app` client

```csharp
new Client
{
    ClientId = "web_app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://localhost:5002/signin-oidc" },
    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "api1" },

    AccessTokenType = AccessTokenType.Reference, // opaque handle, revocable
    AccessTokenLifetime = 900                    // 15 minutes
}
```

### `api1_resource` with an introspection secret

```csharp
new ApiResource("api1_resource")
{
    Scopes = { "api1" },
    ApiSecrets = { new Secret("api1_secret".Sha256()) } // used to authenticate introspection
}
```

## API side

The API validating these tokens must be configured to introspect (e.g. `AddOAuth2Introspection`) using `api1_resource` as the client id and the plaintext secret as the client secret. Without a configured `ApiSecret`, introspection fails with `401`.

> Common pitfall: reference tokens require a network round-trip to introspection on every call, and depend on IdentityServer being reachable. That is the trade-off for immediate revocability — appropriate for a sensitive API, less so for very high-throughput ones.
