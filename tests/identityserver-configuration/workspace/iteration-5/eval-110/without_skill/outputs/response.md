# Custom `IResourceValidator` in Duende IdentityServer

`IResourceValidator` is the extensibility point that validates the resources (scopes) a client requests at the authorize and token endpoints. The built-in implementation is `DefaultResourceValidator`. You can implement your own and register it, and you can wrap the default to add custom rules on top of the standard behavior.

## The Validator (wrapping the default)

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

    public async Task<ResourceValidationResult> ValidateRequestedResourcesAsync(
        ResourceValidationRequest request)
    {
        // request.Client   -> the requesting client
        // request.Scopes   -> the requested scopes

        // Example custom rule
        if (request.Scopes.Contains("admin") && request.Client.ClientId != "trusted-app")
        {
            // reject or filter the request as appropriate
            return new ResourceValidationResult();
        }

        // Fall back to the default validation behavior
        return await _inner.ValidateRequestedResourcesAsync(request);
    }
}
```

## Registration

Register your validator, and because it depends on the default validator, make the default available in DI:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

builder.Services.AddTransient<DefaultResourceValidator>();
idsvrBuilder.AddResourceValidator<CustomResourceValidator>();
```

## Key Points

- Implement `IResourceValidator.ValidateRequestedResourcesAsync(ResourceValidationRequest request)`.
- Use `request.Client` and `request.Scopes` to inspect what was requested and apply your rules.
- Register via `AddResourceValidator<T>()` on the IdentityServer builder.
- When wrapping the default, register `DefaultResourceValidator` in DI so it can be injected into your decorator.
