# FAPI 2.0 with IdentityServer

FAPI 2.0 Security Profile requires: authorization code + PKCE (S256), PAR, sender-constrained tokens (DPoP or mTLS), strong client authentication (private_key_jwt or mTLS), strong algorithms (PS256/ES256), short-lived auth codes, `iss` response parameter, no implicit/ROPC.

## Server

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitIssuerIdentificationResponseParameter = true;   // RFC 9207
    options.AllowedJwtAlgorithms = ["PS256", "ES256"];
    options.PushedAuthorization.Required = true;
    options.PushedAuthorization.Lifetime = TimeSpan.FromMinutes(1);
    options.DPoP.ServerClockSkew = TimeSpan.FromSeconds(10);
    options.Endpoints.EnableJwtRequestUri = false;
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients)
.AddJwtBearerClientAuthentication();   // private_key_jwt

builder.Services.AddDistributedMemoryCache(); // use Redis in production
```

## Client

```csharp
new Client
{
    ClientId = "fapi2_client",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    AllowPlainTextPkce = false,
    RequireClientSecret = true,
    ClientSecrets =
    {
        new Secret { Type = IdentityServerConstants.SecretTypes.JsonWebKey, Value = clientPublicJwk }
    },
    RedirectUris = { "https://tpp.example.com/cb" },
    AllowedScopes = { "openid", "accounts" },

    RequirePushedAuthorization = true,
    RequireDPoP = true,
    DPoPValidationMode = DPoPTokenExpirationValidationMode.Nonce,
    RequireRequestObject = false,   // optional for FAPI 2.0 (needed for FAPI Message Signing)

    AccessTokenLifetime = 300,
    AuthorizationCodeLifetime = 60,
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    AllowedIdentityTokenSigningAlgorithms = { "PS256" }
}
```

Resource servers must validate DPoP (`ConfigureDPoPTokensForScheme`). Also add strict TLS, and note full FAPI certification needs additional items (e.g. signing key configuration with PS256 via `AddSigningCredential(key, "PS256")`).
