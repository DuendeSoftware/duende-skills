# JAR with an RSA key for `secure_app`

## Client configuration

```csharp
new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secureapp.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    RequireRequestObject = true,   // authorize requests must be signed request objects

    ClientSecrets =
    {
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = publicRsaJwkJson   // PUBLIC key only
        }
    }
}
```

Also ensure the signing algorithm (e.g. RS256) is allowed: `options.AllowedJwtAlgorithms = ["RS256", "PS256"]` in `AddIdentityServer`.

## Registering the signing key
The client generates an RSA key pair and keeps the private key. Only the public key is registered on the server as a `JsonWebKey` secret (JWK JSON string) — or alternatively as an `X509CertificateBase64` secret. IdentityServer uses it to verify request object signatures. Example JWK creation:

```csharp
var rsa = RSA.Create(2048);
var key = new RsaSecurityKey(rsa) { KeyId = Guid.NewGuid().ToString("N") };
var jwk = JsonWebKeyConverter.ConvertFromRSASecurityKey(key); // public parts only when you export
var publicJson = JsonSerializer.Serialize(jwk);
```

## Why it's tamperproof
Normally authorize parameters (scope, redirect_uri, etc.) are plain query string values the browser or any intermediary can modify. With JAR, the parameters are bundled in a JWT signed with the client's private key and passed in the `request` parameter. IdentityServer verifies the signature against the registered public key; any modification invalidates it. This gives integrity and client authentication (non-repudiation) of the request; with JWE encryption you'd also get confidentiality. With `RequireRequestObject = true`, unsigned requests are rejected, so attackers can't bypass it. The request object should carry `iss` (client_id), `aud` (the IdentityServer issuer), `exp`/`nbf`, and a `jti` to limit replay.
