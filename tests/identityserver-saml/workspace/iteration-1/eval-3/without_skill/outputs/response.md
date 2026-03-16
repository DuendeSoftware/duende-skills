# Customizing SAML Claim-to-Attribute Mapping

To map claims to custom SAML attribute names, you can configure custom claim mappings in your SAML service provider configuration.

## Approach 1: Use the ClaimMappings Dictionary

The simplest approach is to use the `ClaimMappings` property on your service provider:

```csharp
var sp = new SamlServiceProvider
{
    EntityId = "https://legacy-crm.example.com",
    ClaimMappings = new Dictionary<string, string>
    {
        ["urn:custom:email"] = ClaimTypes.Email,
        ["urn:custom:name"] = ClaimTypes.Name,
        ["urn:custom:role"] = ClaimTypes.Role,
    }
};
```

## Approach 2: Create a Custom Claim Mapper

For more control, implement a custom claim mapping service:

```csharp
public class CustomClaimsMapper : IClaimsMapper
{
    public IEnumerable<SamlAttribute> MapClaims(IEnumerable<Claim> claims)
    {
        var attributes = new List<SamlAttribute>();
        
        foreach (var claim in claims)
        {
            var name = claim.Type switch
            {
                ClaimTypes.Email => "urn:custom:email",
                ClaimTypes.Name => "urn:custom:name",
                _ => claim.Type
            };

            attributes.Add(new SamlAttribute
            {
                Name = name,
                Value = claim.Value
            });
        }

        return attributes;
    }
}
```

Register it:

```csharp
builder.Services.AddSingleton<IClaimsMapper, CustomClaimsMapper>();
```

## Key Points

- ClaimMappings on the service provider is the simplest approach for static mappings
- For dynamic or complex mapping logic, implement a custom mapper
- You can use different mappings per service provider
- Test your mappings with the SP to ensure they accept the attribute format
