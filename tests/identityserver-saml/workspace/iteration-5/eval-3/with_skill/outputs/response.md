# Mapping Claims to Custom SAML Attribute URIs

In Duende IdentityServer's SAML IdP, claims become `<saml:Attribute>` elements according to a **claim pipeline**. Understanding the pipeline explains *which* claims are even available to map:

```
AllowedScopes (identity resources)   → filters which claim types are available
        ↓
RequestedClaimTypes (optional)       → narrows to specific claims
        ↓
ClaimMappings (OIDC name → SAML URI) → emitted as <saml:Attribute>
```

The key takeaway: **`ClaimMappings` only maps claims that actually reach it.** If `AllowedScopes` doesn't include an identity resource that contains a claim type, that claim never flows into the mapping stage, and no amount of `ClaimMappings` config will emit it.

## Per-SP mapping with `ClaimMappings`

Set the `ClaimMappings` dictionary on the individual `SamlServiceProvider`. The **key** is the OIDC/internal claim name; the **value** is the SAML attribute URI it should be emitted as:

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "Example SP",

    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://sp.example.com/acs",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],

    // Prerequisite: the identity resources here must contain the
    // 'email' and 'department' claim types, otherwise they never
    // reach ClaimMappings.
    AllowedScopes = ["openid", "profile", "email", "department"],

    // Optional narrowing to just the claims you care about
    RequestedClaimTypes = ["email", "department"],

    // OIDC claim name (key)  →  SAML attribute URI (value)
    ClaimMappings = new Dictionary<string, string>
    {
        ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["department"] = "urn:custom:department"
    }
}
```

This produces attributes like:

```xml
<saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress">
  <saml:AttributeValue>alice@example.com</saml:AttributeValue>
</saml:Attribute>
<saml:Attribute Name="urn:custom:department">
  <saml:AttributeValue>Engineering</saml:AttributeValue>
</saml:Attribute>
```

> Note: for `department` to be available you need an identity resource that emits the `department` claim type, and the user's profile must actually carry that claim.

## Global defaults with `DefaultClaimMappings`

If several SPs share the same mappings, set them once on `SamlOptions.DefaultClaimMappings`. These apply globally; a per-SP `ClaimMappings` overrides the default for that SP.

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(saml =>
    {
        saml.DefaultClaimMappings = new Dictionary<string, string>
        {
            ["name"]  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
            ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
            ["role"]  = "http://schemas.xmlsoap.org/ws/2005/05/identity/role"
        };
    });
```

## Summary

- Use **`ClaimMappings`** on the `SamlServiceProvider` for per-SP attribute URIs — key = OIDC claim name, value = SAML attribute URI.
- Ensure **`AllowedScopes`** includes the identity resource(s) that carry those claim types, or they'll never reach the mapping stage.
- Use **`SamlOptions.DefaultClaimMappings`** for global defaults shared across SPs; per-SP mappings override them.
