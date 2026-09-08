# Mapping Claims to Custom SAML Attribute URIs

When acting as a SAML IdP, you frequently need to rename your internal claim types (like `email` or `department`) to the specific attribute URIs a service provider expects. This is done with a claim/attribute mapping configuration on the service provider.

## Typical approach

Most SAML implementations for IdentityServer expose a mapping collection on the service provider registration where you associate an incoming claim type with the outgoing SAML attribute name:

```csharp
new ServiceProvider
{
    EntityId = "https://sp.example.com",
    ClaimsMapping = new Dictionary<string, string>
    {
        // internal claim type  ->  SAML attribute URI
        ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["department"] = "urn:custom:department"
    }
}
```

The dictionary key is your internal claim name, and the value is the SAML attribute `Name` that will appear in the assertion:

```xml
<saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress">
  <saml:AttributeValue>user@example.com</saml:AttributeValue>
</saml:Attribute>
```

## Making sure the claims are available

A mapping only works if the claim is actually issued for the user in the first place. So:

1. Make sure the user's profile/identity actually contains `email` and `department` claims. This usually comes from your `IProfileService` or the identity resources associated with the requested scopes.
2. Ensure the SP is allowed to receive those claims (via the scopes/identity resources you grant it).
3. Then map them to the desired attribute URIs.

## Global vs per-SP

- **Per service provider**: use the SP-level mapping dictionary shown above when different SPs need different attribute URIs.
- **Global default**: many implementations let you configure a default set of claim-to-attribute mappings at the options level so you don't repeat common ones (like email and name) on every SP.

## Recommendation

Because the exact property name (`ClaimsMapping`, `AttributeMapping`, etc.) and the options-level default vary by SAML library, verify these against your specific SAML plugin's documentation and its sample configuration.
