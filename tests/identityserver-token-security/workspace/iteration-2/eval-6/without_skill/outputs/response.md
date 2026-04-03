# FAPI 2.0 Compliant Configuration

FAPI 2.0 (Financial-grade API) is a security profile for high-value API interactions. Here's a configuration that meets many of its requirements:

## Server Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR globally
    options.PushedAuthorization.Required = true;
})
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "fapi_client",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = true,
            ClientSecrets = { new Secret("strong_secret".Sha256()) },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true,
            
            // Require signed request objects
            RequireRequestObject = true
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## FAPI 2.0 Key Requirements

1. **Confidential clients only** - No public clients
2. **PKCE required** - Prevents authorization code interception
3. **Sender-constrained tokens** - Use DPoP or mTLS to bind tokens
4. **PAR required** - Push authorization parameters via back channel
5. **Short-lived authorization codes** - Should be under 60 seconds
6. **No refresh token rotation** - Use reuse mode to prevent issues

## Notes

- FAPI 2.0 is primarily used in financial services, open banking, and government
- You'll want to use strong signing algorithms like PS256 or ES256
- Consider using certificate-based client authentication instead of shared secrets
- The full FAPI 2.0 conformance requires careful testing against the FAPI conformance suite
