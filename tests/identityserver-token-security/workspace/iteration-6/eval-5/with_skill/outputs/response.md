# JAR for `secure_app`

## Client configuration

```csharp
new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secureapp.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    RequireRequestObject = true,   // always require signed request objects

    ClientSecrets =
    {
        new Secret
        {
            // RSA public key as JWK
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{'e':'AQAB','kid':'...','kty':'RSA','n':'...'}"
        }
        // or: Type = SecretTypes.X509CertificateBase64,
        //     Value = Convert.ToBase64String(cert.Export(X509ContentType.Cert))
    }
}
```

## How the signing key is registered
The client keeps the RSA **private** key. Only the **public** key is registered on the client as a `ClientSecret`, either as a `JsonWebKey` secret (JWK JSON) or an `X509CertificateBase64` secret (base64 of the exported certificate). IdentityServer verifies the request object signature against it. The same key can also be used for `private_key_jwt` client authentication.

## Why JAR is tamperproof
Normally `scope`, `redirect_uri` etc. are plain query-string values that a user or browser could alter. With JAR the client wraps all authorization parameters in a JWT, signs it with its private key, and sends it as the `request` parameter. IdentityServer validates the signature against the public key registered for the client, so any change to the parameters invalidates the signature: the parameters are **tamperproof** and the request is authenticated as coming from that client. `RequireRequestObject = true` makes unsigned requests get rejected so it can't be bypassed.

Inside IdentityServer, request object values are available via `RequestObjectValues` on `ValidatedAuthorizeRequest`, or from `IIdentityServerInteractionService.GetAuthorizationContextAsync` in UI code.

For `request_uri` (by reference), processing is disabled by default (`options.Endpoints.EnableJwtRequestUri`) because of SSRF risk — prefer PAR.
