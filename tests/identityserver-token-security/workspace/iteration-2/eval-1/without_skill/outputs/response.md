# Enabling DPoP for a Client

DPoP (Demonstrating Proof of Possession) is a mechanism that binds tokens to a client's cryptographic key. This prevents stolen tokens from being used by a third party.

## Client Configuration

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },
    
    // Enable DPoP - the client must provide a proof token
    Properties = new Dictionary<string, string>
    {
        { "require_dpop", "true" }
    }
}
```

## How DPoP Works

DPoP works by having the client generate an asymmetric key pair and include a proof token (a signed JWT) in the `DPoP` header of token requests and API calls. The server validates this proof token and binds the access token to the key.

The access token will contain a confirmation claim (`cnf`) that includes the key fingerprint, ensuring only the key holder can use the token.

## Clock Skew

For clock skew tolerance, you can typically configure this through the token validation parameters. A 2-minute skew is reasonable:

```csharp
// On the API side
options.TokenValidationParameters.ClockSkew = TimeSpan.FromMinutes(2);
```

## Notes

- DPoP is defined in RFC 9449
- The client authenticates normally with its secret, and DPoP adds an additional layer of token binding
- Make sure your API also supports DPoP validation
