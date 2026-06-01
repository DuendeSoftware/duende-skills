# Configuring Claim-to-SAML Attribute Mappings

## The Claim Pipeline

In Duende IdentityServer's SAML support, claims flow through a pipeline:

```
AllowedScopes (identity resources) → filters available claim types
    ↓
RequestedClaimTypes (optional narrowing) → selects specific claims
    ↓
ClaimMappings (OIDC claim name → SAML attribute URI) → output as <saml:Attribute>
```

**Important:** If `AllowedScopes` doesn't include a resource containing a claim type, that claim won't reach `ClaimMappings`. For example, to map `email`, you need `AllowedScopes` to include a scope whose identity resource defines the `email` claim type (typically the built-in `email` scope).

## Per-SP Claim Mappings

Configure `ClaimMappings` on the `SamlServiceProvider` to map OIDC claim names (keys) to SAML attribute URIs (values):

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
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
    AllowedScopes = ["openid", "profile", "email"],
    ClaimMappings = new Dictionary<string, string>
    {
        ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["department"] = "urn:custom:department"
    }
}
```

## Global Default Claim Mappings

Use `SamlOptions.DefaultClaimMappings` to set mappings that apply to all SPs unless overridden per-SP:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Saml.DefaultClaimMappings = new Dictionary<string, string>
    {
        ["name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
        ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["role"] = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
    };
});
```

Per-SP `ClaimMappings` override these defaults.

## Notes

- The dictionary key is the OIDC claim name (e.g., `email`, `name`, `department`)
- The dictionary value is the SAML attribute URI that appears in the `<saml:Attribute Name="...">` element
- Make sure `AllowedScopes` includes a scope whose identity resource contains the claim type you want to map — otherwise it won't be available
- For the `department` claim, ensure you have a custom identity resource that includes it
