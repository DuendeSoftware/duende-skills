# Using Reference Access Tokens for `web_app`

To be able to revoke access tokens immediately, switch the client from JWT to reference tokens and configure the API resource so it can introspect them.

## Why reference tokens allow revocation

JWT access tokens are self-contained and validated locally by the API using IdentityServer's signing keys. Because nothing is stored on the server, a JWT stays valid until it expires — you can't really "revoke" it mid-flight (short of key rotation or maintaining a blocklist yourself). Reference tokens, on the other hand, are just an opaque identifier that points to data held in IdentityServer's store, so deleting/revoking that stored data invalidates the token immediately. The API validates a reference token by calling the introspection endpoint.

## Client changes

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

    AccessTokenType = AccessTokenType.Reference,
    AccessTokenLifetime = 900 // 15 minutes
}
```

## API resource with a secret for introspection

Because introspection is an authenticated endpoint, the API resource needs a secret:

```csharp
new ApiResource("api1_resource")
{
    Scopes = { "api1" },
    ApiSecrets = { new Secret("api1_secret".Sha256()) }
}
```

The API then configures introspection using the resource name `api1_resource` and the shared secret. If no `ApiSecret` is configured, introspection calls will be rejected.
