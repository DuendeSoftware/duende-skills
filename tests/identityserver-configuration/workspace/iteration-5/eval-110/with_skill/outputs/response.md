# Custom `IResourceValidator` in Duende IdentityServer v8

`IResourceValidator` runs at the authorize/token endpoints and validates the resources (scopes + resource indicators) a client requests. The default implementation is `DefaultResourceValidator`. To *wrap* rather than replace it, inject the default into your validator, delegate to it, and add your own rules.

> **v8 breaking change:** `ValidateRequestedResourcesAsync` gained a `CancellationToken` parameter. Implementations written for v7 or earlier must add it to compile.

## The Validator (decorating the default)

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;

public class CustomResourceValidator : IResourceValidator
{
    private readonly DefaultResourceValidator _inner;

    public CustomResourceValidator(DefaultResourceValidator inner)
    {
        _inner = inner;
    }

    // NOTE: the CancellationToken parameter was ADDED in v8.
    public async Task<ResourceValidationResult> ValidateRequestedResourcesAsync(
        ResourceValidationRequest request, CancellationToken cancellationToken)
    {
        // Inspect what the client asked for
        var client            = request.Client;             // the requesting Client
        var scopes            = request.Scopes;             // requested scope names
        var resourceIndicators = request.ResourceIndicators; // RFC 8707 resource params

        // Example custom rule: block a sensitive scope for certain resource indicators
        if (scopes.Contains("payments.write") &&
            resourceIndicators.Any(r => r == "urn:public-api"))
        {
            var failed = new ResourceValidationResult();
            // ... mark invalid scopes / return an empty/invalid result as appropriate ...
            return failed;
        }

        // Delegate to the default validator for the standard behavior
        return await _inner.ValidateRequestedResourcesAsync(request, cancellationToken);
    }
}
```

## Registration

Because you're decorating the default validator, you must **also register `DefaultResourceValidator`** so it can be resolved and injected into your wrapper:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Make the default resolvable so the decorator can depend on it
builder.Services.AddTransient<DefaultResourceValidator>();

// Register the custom validator (replaces the registration used by IdentityServer)
idsvrBuilder.AddResourceValidator<CustomResourceValidator>();
```

## Key Points

- **Method signature:** `Task<ResourceValidationResult> ValidateRequestedResourcesAsync(ResourceValidationRequest request, CancellationToken cancellationToken)` — the `CancellationToken` is the v8 addition.
- **`AddResourceValidator<CustomResourceValidator>()`** registers your validator on the IdentityServer builder.
- **`services.AddTransient<DefaultResourceValidator>()`** is required when wrapping/decorating, because `AddResourceValidator<T>()` replaces the default registration — without this, the default can't be injected into your decorator.
- **`ResourceValidationRequest`** exposes `Client`, `Scopes`, and `ResourceIndicators` (the RFC 8707 `resource` parameters), which is what you inspect to implement cross-scope rules, tenant checks, or resource-indicator policy.
