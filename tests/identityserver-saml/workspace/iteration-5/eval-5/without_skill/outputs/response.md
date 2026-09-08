# Generating a Custom SAML NameID

By default a SAML IdP usually uses the subject (`sub`) claim as the `NameID` in the assertion. To use a different value — like an `employee_id` claim — you customize the NameID generation. Most SAML libraries for IdentityServer expose either a delegate/callback on the service provider or an interface you can implement.

## Option A: Interface/service implementation

Implement the NameID generation service and read the desired claim from the authenticated user:

```csharp
public class EmployeeIdNameIdService : INameIdGenerator
{
    public Task<string> GenerateNameId(ClaimsPrincipal user, ServiceProvider sp)
    {
        var employeeId = user.FindFirst("employee_id")?.Value;
        if (string.IsNullOrEmpty(employeeId))
        {
            throw new InvalidOperationException("employee_id claim is missing.");
        }
        return Task.FromResult(employeeId);
    }
}
```

Register it:

```csharp
builder.Services.AddScoped<INameIdGenerator, EmployeeIdNameIdService>();
```

## Option B: Map the NameID from a claim in configuration

Some implementations let you specify which claim becomes the NameID directly on the SP registration:

```csharp
new ServiceProvider
{
    EntityId = "https://sp.example.com",
    NameIdClaimType = "employee_id",
    NameIdFormat = "urn:oasis:names:tc:SAML:2.0:nameid-format:unspecified"
}
```

This avoids custom code if all you need is a straight claim-to-NameID mapping.

## Things to watch

1. **Claim availability**: `employee_id` must be issued for the user (through your profile service or identity resources). If it isn't present, decide whether to fail the request or fall back to `sub`.
2. **NameID format**: Pick an appropriate `NameIdFormat` (e.g., `unspecified`, `persistent`, or `emailAddress`) and make sure it matches what the SP expects.
3. **Stability**: The SP will key the user's account off this NameID, so it should be stable and unique per user.

## Recommendation

The exact interface name and registration method depend on the SAML library you're using with IdentityServer, so confirm the NameID extensibility API against its documentation. If a simple configuration-based claim mapping is available, prefer it over custom code.
