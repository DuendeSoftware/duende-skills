# Custom SAML Claim-to-Attribute Mapping

To customize how claims are mapped to SAML attributes, implement the `ISamlClaimsMapper` interface.

## Implementation

```csharp
// CustomSamlClaimsMapper.cs
using System.Security.Claims;
using Duende.IdentityServer.Saml.Models;
using Duende.IdentityServer.Saml;

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

```csharp
// Program.cs
builder.Services.AddTransient<ISamlClaimsMapper, CustomSamlClaimsMapper>();
```

## Important Warning

**Implementing `ISamlClaimsMapper` completely replaces the default claim mapping.** The default mappings configured in `IdentityServerOptions.Saml.DefaultClaimMappings` are **not** applied when you provide a custom mapper. You must handle all claim-to-attribute mappings yourself in your implementation.
