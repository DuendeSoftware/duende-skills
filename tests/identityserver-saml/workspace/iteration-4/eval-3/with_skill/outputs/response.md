# Configuring Custom Claim-to-SAML-Attribute URI Mappings

SAML assertions carry claims as `<saml:Attribute>` elements. The `Name` attribute of each element is a URI that the service provider uses to identify the claim — these URIs are often dictated by the SP vendor or SAML federation standard. Duende IdentityServer lets you control this mapping at two levels: globally (across all SPs) and per-SP.

---

## How the Claim Pipeline Works

Before diving into configuration, understand how claims reach the SAML assertion:

```
1. AllowedScopes  (e.g., ["openid", "profile", "email", "custom"])
        ↓  IdentityResources define which claim types belong to each scope
2. Available claim types (e.g., "sub", "email", "name", "department")
        ↓  RequestedClaimTypes optionally narrows this list
3. ClaimMappings  (OIDC claim name → SAML attribute URI)
        ↓
4. SAML assertion: <saml:Attribute Name="http://schemas.xmlsoap.org/...">
```

`ClaimMappings` only renames claims that exist. If a claim type isn't in an identity resource that's in `AllowedScopes`, it will never reach `ClaimMappings` regardless of what you put there.

---

## Option 1: Per-SP ClaimMappings (Most Common)

Set `ClaimMappings` directly on the `SamlServiceProvider` registration. This is a `Dictionary<string, string>` where:
- **Key**: the OIDC/internal claim type name (e.g., `"email"`, `"department"`)
- **Value**: the SAML attribute URI the SP expects

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "Example SP",

    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://sp.example.com/saml/acs",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],

    // The SP needs access to the scopes that contain these claims
    AllowedScopes = ["openid", "profile", "email", "custom_profile"],

    ClaimMappings = new Dictionary<string, string>
    {
        // Standard WS-Federation URIs (common vendor expectation)
        ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["name"]       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
        ["given_name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname",
        ["family_name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname",

        // Custom URN for your internal claim
        ["department"] = "urn:custom:department",

        // Another custom attribute
        ["employee_id"] = "urn:example:employeeNumber"
    },

    DefaultNameIdFormat = SamlNameIdFormat.EmailAddress,
    Enabled = true
}
```

The generated SAML assertion will contain:

```xml
<saml:AttributeStatement>
    <saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
                    NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri">
        <saml:AttributeValue>alice@example.com</saml:AttributeValue>
    </saml:Attribute>
    <saml:Attribute Name="urn:custom:department"
                    NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri">
        <saml:AttributeValue>Engineering</saml:AttributeValue>
    </saml:Attribute>
</saml:AttributeStatement>
```

---

## Option 2: Global Default Mappings (Applies to All SPs)

Use `SamlOptions.DefaultClaimMappings` when the same URI conventions apply to all your SPs. Per-SP `ClaimMappings` override these defaults for a specific SP.

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(saml =>
    {
        // These apply to every SP that doesn't define its own ClaimMappings
        saml.DefaultClaimMappings = new Dictionary<string, string>
        {
            ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
            ["name"]       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
            ["given_name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname",
            ["family_name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname",
            ["role"]       = "http://schemas.xmlsoap.org/ws/2005/05/identity/role",
            ["department"] = "urn:custom:department"
        };
    })
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

Per-SP `ClaimMappings` on individual `SamlServiceProvider` registrations take precedence over `DefaultClaimMappings`. They do **not** merge — if a per-SP mapping is set, it fully replaces the global defaults for that SP.

---

## Ensuring Claims Are Available: Identity Resources

`ClaimMappings` can only map claims that actually exist in the assertion. You need an `IdentityResource` that declares each custom claim type, and the SP must include that resource in `AllowedScopes`.

```csharp
// Define an identity resource that includes your custom claims
new IdentityResource
{
    Name = "custom_profile",
    DisplayName = "Custom Profile",
    UserClaims = ["department", "employee_id", "cost_center"]
}
```

Then in the SP registration:

```csharp
AllowedScopes = ["openid", "profile", "email", "custom_profile"],
```

And in your `IProfileService` (or `TestUsers`), ensure the user's claims include `department` and `employee_id`.

---

## Narrowing Claims with RequestedClaimTypes

If `AllowedScopes` grants access to many claims but this particular SP only needs a subset, use `RequestedClaimTypes` to narrow what's included in the assertion:

```csharp
new SamlServiceProvider
{
    EntityId = "https://limited-sp.example.com",
    AllowedScopes = ["openid", "profile", "email", "custom_profile"],

    // Only include these two — even though profile and custom_profile grant more
    RequestedClaimTypes = ["email", "department"],

    ClaimMappings = new Dictionary<string, string>
    {
        ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["department"] = "urn:custom:department"
    }
}
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| `department` doesn't appear in assertion | No `IdentityResource` containing `"department"` in `AllowedScopes` | Add a custom `IdentityResource` with `UserClaims = ["department"]` and add it to `AllowedScopes` |
| Claim appears with wrong URI | Per-SP `ClaimMappings` not set; global default used | Add explicit `ClaimMappings` on the `SamlServiceProvider` |
| Claim appears without a URI mapping | Claim is in assertion but has no mapping entry | Add an entry to `ClaimMappings`; unmapped claims pass through with their OIDC name |
| SP reports unknown attribute | SP vendor expects a specific URI not matching your mapping | Check SP documentation for required attribute URIs |

---

## Full Example: Both Mappings Together

```csharp
// Global defaults in SamlOptions
.AddSaml(saml =>
{
    saml.DefaultClaimMappings = new Dictionary<string, string>
    {
        ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["name"]  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
    };
})

// SP-specific override — replaces defaults entirely for this SP
.AddInMemorySamlServiceProviders(new[]
{
    new SamlServiceProvider
    {
        EntityId = "https://crm.contoso.com",
        AllowedScopes = ["openid", "profile", "email", "custom_profile"],
        ClaimMappings = new Dictionary<string, string>
        {
            // Override the global email mapping (same URI in this case)
            ["email"]      = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
            // SP-specific custom claim
            ["department"] = "urn:custom:department"
            // Note: "name" is NOT in this per-SP mapping, so it won't appear
            // even though it's in DefaultClaimMappings
        }
    }
});
```

> Because per-SP `ClaimMappings` fully replaces `DefaultClaimMappings`, if you want global defaults **plus** extras, you'll need to repeat the global entries in the per-SP mapping. This is by design — it gives precise control per SP.
