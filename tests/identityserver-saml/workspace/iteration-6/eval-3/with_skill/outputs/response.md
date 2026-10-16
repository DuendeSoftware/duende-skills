# Mapping claims to custom SAML attribute URIs

Use `ClaimMappings` on the `SamlServiceProvider` (OIDC claim name → SAML attribute name):

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "Example SP",
    AssertionConsumerServiceUrls = [ /* HTTP-POST ACS */ ],
    AllowedScopes = ["openid", "email", "company"],   // must include resources that contain the claims
    RequestedClaimTypes = ["email", "department"],     // optional narrowing
    ClaimMappings = new Dictionary<string, string>
    {
        ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["department"] = "urn:custom:department"
    }
};
```

For global defaults use `SamlOptions.DefaultClaimMappings`; per-SP `ClaimMappings` override them:

```csharp
.AddSaml(saml => saml.DefaultClaimMappings = new Dictionary<string, string>
{
    ["name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
});
```

## The pipeline
```
AllowedScopes (identity resources) → RequestedClaimTypes (optional) → ClaimMappings → <saml:Attribute>
```
So `department` only arrives if:
1. an `IdentityResource` (e.g. `new IdentityResource("company", ["department"])`) containing it is in the SP's `AllowedScopes`, and
2. your `IProfileService` actually issues the claim.

If `AllowedScopes` doesn't cover the claim, it never reaches `ClaimMappings` (the most common reason for a missing attribute). Omitting `AllowedScopes` yields no claims at all. For more complex transformation, replace `ISaml2SsoResponseGenerator`.
