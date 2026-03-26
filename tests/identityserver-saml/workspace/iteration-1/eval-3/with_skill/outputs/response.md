# Custom Claim-to-Attribute Mapping in Duende IdentityServer SAML

To customize how claims are mapped to SAML attributes, implement the `ISamlClaimsMapper` interface. This gives you full control over which SAML attributes appear in assertions and how they're named.

## Important Warning

**Implementing `ISamlClaimsMapper` completely replaces the default claim mapping.** The default mappings configured in `IdentityServerOptions.Saml.DefaultClaimMappings` are **not applied** when you provide a custom mapper. You must handle all claims yourself.

## Custom Mapper Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;

public class CustomSamlClaimsMapper : ISamlClaimsMapper
{
    public Task<IEnumerable<SamlAttribute>> MapClaimsAsync(
        IEnumerable<Claim> claims,
        SamlServiceProvider serviceProvider)
    {
        var attributes = new List<SamlAttribute>();

        foreach (var claim in claims)
        {
            var attributeName = claim.Type switch
            {
                "email" => "urn:custom:email",
                "name" => "urn:custom:displayname",
                "given_name" => "urn:custom:firstname",
                "family_name" => "urn:custom:lastname",
                "role" => "urn:custom:role",
                _ => $"urn:custom:{claim.Type}"
            };

            attributes.Add(new SamlAttribute
            {
                Name = attributeName,
                Values = [claim.Value]
            });
        }

        return Task.FromResult<IEnumerable<SamlAttribute>>(attributes);
    }
}
```

## Registration

Register the custom mapper as a transient service:

```csharp
builder.Services.AddTransient<ISamlClaimsMapper, CustomSamlClaimsMapper>();
```

## Per-SP Custom Mapping

The `MapClaimsAsync` method receives the `SamlServiceProvider` as a parameter, so you can customize mappings per service provider:

```csharp
public Task<IEnumerable<SamlAttribute>> MapClaimsAsync(
    IEnumerable<Claim> claims,
    SamlServiceProvider serviceProvider)
{
    if (serviceProvider.EntityId == "https://legacy-sp.example.com")
    {
        // Legacy SP expects urn:custom:* format
        return MapLegacyAttributes(claims);
    }

    // Standard mapping for other SPs
    return MapStandardAttributes(claims);
}
```

## Key Points

- `ISamlClaimsMapper` **completely replaces** default mapping — `DefaultClaimMappings` are not applied
- The mapper receives the `SamlServiceProvider` so you can vary behavior per SP
- `SamlAttribute` has `Name` (the attribute name in the assertion) and `Values` (list of values)
- Register as transient with `AddTransient<ISamlClaimsMapper, YourMapper>()`