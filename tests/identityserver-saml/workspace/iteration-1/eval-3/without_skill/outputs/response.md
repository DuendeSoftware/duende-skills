# Custom SAML Attribute Mapping in IdentityServer

To customize how claims are mapped to SAML attributes, you'll need to create a custom claim mapper. Here's how:

## Creating a Custom Claims Mapper

```csharp
using System.Security.Claims;

public class CustomClaimsMapper
{
    public Dictionary<string, string> MapClaims(IEnumerable<Claim> claims)
    {
        var mapped = new Dictionary<string, string>();

        foreach (var claim in claims)
        {
            var attributeName = claim.Type switch
            {
                "email" => "urn:custom:email",
                "name" => "urn:custom:displayname",
                "given_name" => "urn:custom:firstname",
                "family_name" => "urn:custom:lastname",
                _ => claim.Type
            };

            mapped[attributeName] = claim.Value;
        }

        return mapped;
    }
}
```

## Registration

```csharp
builder.Services.AddSingleton<CustomClaimsMapper>();
```

## Usage

You'll need to hook this mapper into the SAML response generation pipeline. The exact approach depends on the extensibility points available, but typically you'd configure it as part of the SAML options or through middleware:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(options =>
    {
        options.ClaimMappings = new Dictionary<string, string>
        {
            ["email"] = "urn:custom:email",
            ["name"] = "urn:custom:displayname"
        };
    });
```

## Notes

- You may need to extend the default mappings rather than completely replacing them
- Test thoroughly with your SP to ensure the attribute format matches expectations
- Consider caching mapped claims for performance