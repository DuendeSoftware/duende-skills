# Mapping Claims to Custom SAML Attribute URIs

SAML 2.0 represents user attributes as `<saml:Attribute>` elements with a `Name` attribute that is typically a URI. When Duende IdentityServer issues a SAML assertion, it needs to know how to translate the claim types that IdentityServer works with internally into the SAML attribute URIs your SP expects.

---

## How Claim Mapping Works

The `ServiceProvider` model has a `ClaimMapping` dictionary that maps:

- **Key** → the claim type as it exists in the user's `ClaimsPrincipal` (the short name or full URI that IdentityServer emits)
- **Value** → the SAML `Attribute Name` URI that should appear in the assertion sent to that SP

This mapping is per-SP, so different service providers can receive different attribute names for the same underlying claim.

---

## Configuration Example

```csharp
new ServiceProvider
{
    EntityId = "https://crm.contoso.com",
    AssertionConsumerServices =
    {
        new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/acs")
    },
    ClaimMapping = new Dictionary<string, string>
    {
        // Standard email claim → WS-Federation/SAML 1.1-style URI
        ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",

        // Custom claim type → custom URN
        ["department"] = "urn:custom:department",

        // Some additional common mappings you may need:
        ["name"]       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
        ["given_name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname",
        ["family_name"]= "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname",
        ["sub"]        = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
    }
}
```

---

## Making Sure the Claims Are Present

The mapping only works if the claim type you reference as the **key** is actually present in the user's token/session. Make sure you:

1. **Include the claim in an `IdentityResource`** so IdentityServer knows it's a valid identity-related claim:

```csharp
new IdentityResource(
    name: "saml_profile",
    displayName: "SAML Profile",
    userClaims: new[] { "email", "department", "given_name", "family_name" }
)
```

2. **Return the claim from your user store** (e.g., `TestUsers`, your `IProfileService`, or `IUserClaimsFactory`) when it is requested.

3. If using `TestUsers`, add the claims directly to the user:

```csharp
new TestUser
{
    SubjectId = "1",
    Username = "alice",
    Claims =
    {
        new Claim("email",      "alice@example.com"),
        new Claim("department", "Engineering"),
        new Claim("given_name", "Alice"),
        new Claim("family_name","Smith"),
    }
}
```

---

## NameID Configuration

The SAML `<NameID>` element (the primary subject identifier) is separate from attribute statements. You can control how it's set via the `ServiceProvider`:

```csharp
new ServiceProvider
{
    EntityId = "https://crm.contoso.com",
    // ...
    // Map the NameID format; defaults to the 'sub' claim
    // Some SPs require a specific NameID format:
    // SamlConstants.NameIdentifierFormats.EmailAddress
    // SamlConstants.NameIdentifierFormats.Persistent
    // SamlConstants.NameIdentifierFormats.Transient
}
```

Consult your SP's metadata or documentation to confirm which `NameIDFormat` it requires.

---

## Verifying the Assertion

After setup, decode a SAML response (base64-decode the `SAMLResponse` POST parameter, then XML-format it) to confirm the attributes appear with the correct `Name` URIs:

```xml
<saml:AttributeStatement>
  <saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress">
    <saml:AttributeValue>alice@example.com</saml:AttributeValue>
  </saml:Attribute>
  <saml:Attribute Name="urn:custom:department">
    <saml:AttributeValue>Engineering</saml:AttributeValue>
  </saml:Attribute>
</saml:AttributeStatement>
```

---

## Summary

| Step | Action |
|------|--------|
| Declare claims | Add claim types to an `IdentityResource` |
| Populate claims | Return them from user store / `IProfileService` |
| Map to SAML URIs | Configure `ClaimMapping` on the `ServiceProvider` |
| Verify | Decode and inspect the SAML assertion XML |
