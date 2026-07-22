# Generating Custom NameID Values from an `employee_id` Claim

## Overview

By default, Duende IdentityServer derives NameID values from well-known claim types (e.g., the `sub` claim for persistent format, or the `email` claim for the EmailAddress format). To use a custom claim such as `employee_id`, you implement the `ISamlNameIdGenerator` extensibility interface and register it with the DI container.

---

## Step 1: Implement `ISamlNameIdGenerator`

```csharp
using Duende.IdentityServer.Saml;

public class EmployeeIdNameIdGenerator : ISamlNameIdGenerator
{
    public Task<NameIdGenerationResult> GenerateAsync(
        NameIdGenerationContext context,
        CancellationToken ct)
    {
        // Attempt to read the custom claim from the authenticated subject
        var employeeId = context.Subject.FindFirst("employee_id")?.Value;

        if (string.IsNullOrEmpty(employeeId))
        {
            // Return a failure result — IdentityServer will send a SAML error response to the SP
            return Task.FromResult(NameIdGenerationResult.Failure(
                StatusCodes.Responder,
                StatusCodes.UnknownPrincipal,
                "The employee_id claim is missing from the user's profile."));
        }

        // Return a success result using the resolved NameID format from the request
        return Task.FromResult(NameIdGenerationResult.Success(
            new NameId(employeeId, context.ResolvedFormat)));
    }
}
```

**Key points:**
- `context.Subject` is a `ClaimsPrincipal` — use `FindFirst("employee_id")` to locate your custom claim.
- `context.ResolvedFormat` is the NameID format negotiated between IdentityServer and the SP (from the SP's `DefaultNameIdFormat` or the AuthnRequest). You can override it by passing a different `SamlNameIdFormat` constant if needed.
- `NameIdGenerationResult.Failure(...)` causes IdentityServer to send a proper SAML error response back to the SP rather than throwing an unhandled exception.

---

## Step 2: Register the Custom Generator

Register your implementation in `Program.cs` **after** the `AddSaml()` call:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);

// Override the default NameID generator with your custom implementation
builder.Services.AddTransient<ISamlNameIdGenerator, EmployeeIdNameIdGenerator>();
```

Since `ISamlNameIdGenerator` is resolved via DI, your class can inject any services it needs (e.g., `IUserService`, `IHttpContextAccessor`, a database repository for employee lookups).

---

## Step 3: Ensure the `employee_id` Claim Reaches the Generator

`ISamlNameIdGenerator` receives the `ClaimsPrincipal` that flows through the SAML pipeline. For the `employee_id` claim to be present, it must be emitted by your profile service. If you're using `TestUsers`, add the claim there; for a real deployment, emit it from `IProfileService.GetProfileDataAsync`:

```csharp
public class MyProfileService : IProfileService
{
    public Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Always include employee_id regardless of requested scopes,
        // or gate it behind a custom scope
        var employeeId = LookupEmployeeId(context.Subject.GetSubjectId());
        context.IssuedClaims.Add(new Claim("employee_id", employeeId));

        // ... other claims
        return Task.CompletedTask;
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

> **Important:** The claim pipeline for SAML is: `AllowedScopes → RequestedClaimTypes → ClaimMappings`. However, `ISamlNameIdGenerator` operates on the **full subject** `ClaimsPrincipal` from your profile service, not just the claims filtered through `AllowedScopes`. As long as your profile service emits `employee_id`, the generator will see it even if `employee_id` is not listed in `AllowedScopes` or `ClaimMappings`.

---

## Step 4: Configure the SP's NameID Format (Optional)

You can set the expected NameID format on the `SamlServiceProvider` registration. Use `Unspecified` for opaque identifiers like employee IDs:

```csharp
new SamlServiceProvider
{
    EntityId = "https://hr.example.com",
    DisplayName = "HR System",
    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://hr.example.com/sso",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],
    AllowedScopes = ["openid", "profile"],

    // Use Unspecified or Persistent for opaque employee IDs
    DefaultNameIdFormat = SamlNameIdFormat.Unspecified,
}
```

---

## Complete Example: Updated `Program.cs`

Starting from your existing `Program.cs` (OIDC-only), here is the full SAML-enabled version with the custom NameID generator:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Saml;

var builder = WebApplication.CreateBuilder(args);

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

// Register the custom NameID generator
builder.Services.AddTransient<ISamlNameIdGenerator, EmployeeIdNameIdGenerator>();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| NameID in assertion is still the `sub` claim | Custom generator not registered, or registered before DI resolves the default | Ensure `AddTransient<ISamlNameIdGenerator, EmployeeIdNameIdGenerator>()` is called **after** `AddIdentityServer()` |
| SP reports "NameID missing" | Generator returns `Failure` | Check that your profile service emits `employee_id` for all users |
| NameID format mismatch | SP expects a specific format, generator uses `context.ResolvedFormat` which differs | Set `DefaultNameIdFormat` on the `SamlServiceProvider` to match what the SP expects, or hardcode the format in `new NameId(value, SamlNameIdFormat.Persistent)` |
| Employee ID claim not on `context.Subject` | Profile service not emitting the claim | Verify `IProfileService.GetProfileDataAsync` adds a `Claim("employee_id", ...)` |
