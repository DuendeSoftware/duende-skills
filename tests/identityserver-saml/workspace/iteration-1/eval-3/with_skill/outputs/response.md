# Custom SAML Claim-to-Attribute Mapping

To customize how claims are mapped to SAML attributes in Duende IdentityServer, implement the `ISamlClaimsMapper` interface. This gives you full control over the attribute names and values in SAML assertions.

> **Important Warning**: Implementing `ISamlClaimsMapper` **completely replaces** the default claim mapping. The default mappings configured in `IdentityServerOptions.Saml.DefaultClaimMappings` are **not applied** when you provide a custom mapper. You must handle all claims yourself.

## Custom ISamlClaimsMapper Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models.Saml;
using Duende.IdentityServer.Saml;

public class LegacySamlClaimsMapper : ISamlClaimsMapper
{
    public Task<IEnumerable<SamlAttribute>> MapClaimsAsync(
        IEnumerable<Claim> claims,
        SamlServiceProvider serviceProvider)
    {
        var attributes = new List<SamlAttribute>();

        foreach (var claim in claims)
        {
            // Map to custom URN format for the legacy SP
            var attributeName = claim.Type switch
            {
                "email" => "urn:custom:email",
                "name" => "urn:custom:name",
                "given_name" => "urn:custom:firstName",
                "family_name" => "urn:custom:lastName",
                "role" => "urn:custom:role",
                _ => $"urn:custom:{claim.Type}" // fallback for any other claims
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

Register the custom mapper as a transient service in your DI container:

```csharp
builder.Services.AddTransient<ISamlClaimsMapper, LegacySamlClaimsMapper>();
```

## Per-SP Mapping

If only some SPs need custom mapping, you can use the `serviceProvider` parameter to branch:

```csharp
public Task<IEnumerable<SamlAttribute>> MapClaimsAsync(
    IEnumerable<Claim> claims,
    SamlServiceProvider serviceProvider)
{
    var attributes = new List<SamlAttribute>();

    foreach (var claim in claims)
    {
        if (serviceProvider.EntityId == "https://legacy-crm.example.com")
        {
            // Legacy SP expects urn:custom:* format
            attributes.Add(new SamlAttribute
            {
                Name = $"urn:custom:{claim.Type}",
                Values = [claim.Value]
            });
        }
        else
        {
            // Standard mapping for other SPs
            attributes.Add(new SamlAttribute
            {
                Name = claim.Type,
                Values = [claim.Value]
            });
        }
    }

    return Task.FromResult<IEnumerable<SamlAttribute>>(attributes);
}
```

## Key Points

- `ISamlClaimsMapper` **completely replaces** all default claim mapping — `DefaultClaimMappings` are not applied when a custom mapper is registered
- The mapper receives the `SamlServiceProvider` so you can customize per-SP
- Each `SamlAttribute` has a `Name` (the attribute name in the SAML assertion) and `Values` (list of attribute values)
- Register as transient via `AddTransient<ISamlClaimsMapper, YourMapper>()`
