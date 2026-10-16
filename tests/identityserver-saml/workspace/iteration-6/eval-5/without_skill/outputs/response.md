# Custom NameID from `employee_id`

Add the claim to the user's claims via your profile service, then tell the SAML layer to use it for NameID. Two options:

1. Per-SP configuration (if supported): set a NameID claim type on the SP registration, e.g. `NameIdClaimType = "employee_id"` and `NameIdFormat = Persistent/Unspecified`.
2. Custom NameID generator service (approximate API):

```csharp
public class EmployeeIdNameIdGenerator : ISamlNameIdGenerator
{
    public Task<SamlNameId> GenerateAsync(SamlNameIdContext ctx)
    {
        var id = ctx.Subject.FindFirst("employee_id")?.Value
                 ?? throw new InvalidOperationException("employee_id missing");
        return Task.FromResult(new SamlNameId(id, SamlNameIdFormat.Persistent));
    }
}
builder.Services.AddTransient<ISamlNameIdGenerator, EmployeeIdNameIdGenerator>();
```

Ensure `IProfileService` issues `employee_id` for the SAML context (otherwise it isn't in the subject's claims), and fail loudly or fall back to `sub` if it's missing. NameIDs should be stable and not reassigned.
