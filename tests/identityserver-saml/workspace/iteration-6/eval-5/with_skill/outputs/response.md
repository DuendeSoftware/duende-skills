# NameID from `employee_id`

Implement `ISamlNameIdGenerator` and register it. Registration order relative to `AddSaml()` doesn't matter (defaults use `TryAdd*`).

```csharp
public class EmployeeNameIdGenerator : ISamlNameIdGenerator
{
    public Task<NameIdGenerationResult> GenerateAsync(
        NameIdGenerationContext context, CancellationToken ct)
    {
        var employeeId = context.Subject.FindFirst("employee_id")?.Value;
        if (employeeId is null)
            return Task.FromResult(NameIdGenerationResult.Failure(
                StatusCodes.Responder, StatusCodes.UnknownPrincipal,
                "Employee ID claim not found."));

        return Task.FromResult(NameIdGenerationResult.Success(
            new NameId(employeeId, context.ResolvedFormat)));
    }
}
```

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);

builder.Services.AddScoped<ISamlNameIdGenerator, EmployeeNameIdGenerator>();
```

Make sure that:
- `employee_id` is present on the subject — issue it from your `IProfileService` (or user store/session claims).
- The SP's `DefaultNameIdFormat` (e.g. `SamlNameIdFormat.Persistent`/`Unspecified`) is among `SamlOptions.SupportedNameIdFormats`; `context.ResolvedFormat` carries the negotiated format.
- If the claim is missing, return a SAML failure (as above) rather than silently falling back to `sub`.

For email-format NameIDs you don't need a generator: set `EmailNameIdClaimType` (global in `SamlOptions` or per-SP).
