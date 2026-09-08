# Custom NameID Generation from an `employee_id` Claim

By default, Duende IdentityServer derives the SAML `NameID` from the subject (`sub`) claim. To use a different claim — here `employee_id` — implement the **`ISamlNameIdGenerator`** extensibility interface. Its `GenerateAsync` method receives a `NameIdGenerationContext` (which exposes the authenticated user's claims via `Subject`) and returns a `NameIdGenerationResult`.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Saml.Services;
using Duende.IdentityServer.Saml.Models;

public class EmployeeIdNameIdGenerator : ISamlNameIdGenerator
{
    public Task<NameIdGenerationResult> GenerateAsync(
        NameIdGenerationContext context, CancellationToken ct)
    {
        // Pull employee_id from the authenticated subject's claims
        var employeeId = context.Subject.FindFirst("employee_id")?.Value;

        // Missing claim → return a SAML failure so the SP gets a proper
        // error status instead of a malformed/empty NameID
        if (string.IsNullOrEmpty(employeeId))
        {
            return Task.FromResult(NameIdGenerationResult.Failure(
                StatusCodes.Responder,
                StatusCodes.UnknownPrincipal,
                "The 'employee_id' claim was not found on the subject."));
        }

        // Success → emit the employee_id as the NameID, honoring the
        // format the pipeline resolved for this request/SP
        return Task.FromResult(NameIdGenerationResult.Success(
            new NameId(employeeId, context.ResolvedFormat)));
    }
}
```

Key points:

- **`context.Subject`** is the `ClaimsPrincipal` for the authenticated user; use `FindFirst("employee_id")` to read the claim.
- **`NameIdGenerationResult.Success(new NameId(value, format))`** returns the NameID. Passing `context.ResolvedFormat` keeps the NameID format consistent with what the request/SP negotiated.
- **`NameIdGenerationResult.Failure(...)`** produces a proper SAML status response (e.g., `Responder` / `UnknownPrincipal`) when the claim is absent — this is much safer than emitting an empty or fabricated identifier.

## Registration

Register your generator in DI. Note that SAML defaults are registered with `TryAdd*`, so **DI ordering doesn't matter** — you don't have to register before `AddSaml()`; your scoped registration takes precedence over the default either way.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);

// Custom NameID generator — order relative to AddSaml() is irrelevant (TryAdd*)
builder.Services.AddScoped<ISamlNameIdGenerator, EmployeeIdNameIdGenerator>();
```

## Make sure the claim is present

`employee_id` must actually be issued for the user. Ensure it's produced by your `IProfileService` / identity resource and that the SP's `AllowedScopes` include the resource carrying it, otherwise `context.Subject` won't contain it and every request will hit the failure branch.
