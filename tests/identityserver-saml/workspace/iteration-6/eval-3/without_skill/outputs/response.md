# Mapping claims to SAML attribute names

In Duende IdentityServer's SAML support, you configure per-service-provider claim-type-to-attribute mappings on the SP registration. Approximately:

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    AssertionConsumerServiceUrls = { new Uri("https://sp.example.com/acs") },
    ClaimMappings =
    {
        ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["department"] = "urn:custom:department"
    }
}
```

Also make sure the claims are actually available: `email` comes from the `email` identity resource, and `department` must be issued by your profile service (`IProfileService`) for the requested context. Only claims that are mapped/allowed end up in the AttributeStatement. If you need transformation logic beyond one-to-one renaming, implement a custom service that builds the attribute list. Exact property names should be verified against your version.
