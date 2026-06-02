# Custom NameID Generation in Duende IdentityServer SAML

To customize the NameID value in SAML assertions, you can implement a custom NameID generator.

## Implementation

```csharp
public class EmployeeIdNameIdGenerator : INameIdGenerator
{
    public Task<string> GenerateAsync(NameIdGenerationContext context)
    {
        var employeeId = context.User.Claims
            .FirstOrDefault(c => c.Type == "employee_id")?.Value;

        if (string.IsNullOrEmpty(employeeId))
        {
            throw new InvalidOperationException("employee_id claim not found");
        }

        return Task.FromResult(employeeId);
    }
}
```

## Registration

Register the custom generator in your DI container:

```csharp
services.AddTransient<INameIdGenerator, EmployeeIdNameIdGenerator>();
```

## Configuration

You may also need to set the NameID format on the service provider:

```csharp
new ServiceProvider
{
    EntityId = "https://sp.example.com",
    NameIdFormat = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
}
```

This ensures the assertion uses your custom value instead of the default subject identifier.
