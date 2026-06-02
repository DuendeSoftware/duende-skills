# Custom NameID Generation from employee_id Claim

Implement the `ISamlNameIdGenerator` interface to derive the SAML NameID from any claim:

```csharp
using Duende.IdentityServer.Saml;
using Duende.IdentityServer.Saml.Models;

public class EmployeeNameIdGenerator : ISamlNameIdGenerator
{
    public Task<NameIdGenerationResult> GenerateAsync(
        NameIdGenerationContext context, CancellationToken ct)
    {
        var employeeId = context.Subject.FindFirst("employee_id")?.Value;

        if (employeeId is null)
        {
            return Task.FromResult(NameIdGenerationResult.Failure(
                StatusCodes.Responder,
                StatusCodes.UnknownPrincipal,
                "Employee ID claim not found."));
        }

        return Task.FromResult(NameIdGenerationResult.Success(
            new NameId(employeeId, context.ResolvedFormat)));
    }
}
```

## Register the Custom Generator

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);

// Register custom NameID generator
builder.Services.AddTransient<ISamlNameIdGenerator, EmployeeNameIdGenerator>();
```

## How It Works

1. `GenerateAsync` receives a `NameIdGenerationContext` that contains:
   - `Subject` — the `ClaimsPrincipal` for the authenticated user
   - `ResolvedFormat` — the NameID format requested by the SP (or the SP's `DefaultNameIdFormat`)
   - `ServiceProvider` — the requesting SP configuration

2. Extract the `employee_id` claim from `context.Subject`

3. If the claim exists, return `NameIdGenerationResult.Success` with a `NameId` containing the value and the resolved format

4. If the claim is missing, return `NameIdGenerationResult.Failure` with appropriate SAML status codes — this results in an error response to the SP

## Ensure the Claim Is Available

Make sure the user's `employee_id` claim is populated in their claims principal. If it comes from a custom identity resource, ensure it's included in the user's claims (e.g., via a profile service or claims store).
