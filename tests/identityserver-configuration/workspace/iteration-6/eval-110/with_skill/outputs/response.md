In v8, `IResourceValidator.ValidateRequestedResourcesAsync` has an extra **`CancellationToken`** parameter (breaking change from v7).

```csharp
using Duende.IdentityServer.Validation;

public class CustomResourceValidator : IResourceValidator
{
    private readonly DefaultResourceValidator _inner;

    public CustomResourceValidator(DefaultResourceValidator inner) => _inner = inner;

    public async Task<ResourceValidationResult> ValidateRequestedResourcesAsync(
        ResourceValidationRequest request, CancellationToken cancellationToken)
    {
        // Run the default validation first
        var result = await _inner.ValidateRequestedResourcesAsync(request, cancellationToken);
        if (!result.Succeeded)
            return result;

        // request.Client, request.Scopes, request.ResourceIndicators (RFC 8707)
        // Custom rules, e.g. tenant checks or cross-scope rules:
        if (request.Scopes.Contains("admin") && !request.Client.ClientId.StartsWith("internal."))
        {
            return new ResourceValidationResult(); // no resources => failure
        }

        return result;
    }
}
```

Registration:
```csharp
var idsvrBuilder = builder.Services.AddIdentityServer();

// the default must be resolvable so that it can be wrapped
builder.Services.AddTransient<DefaultResourceValidator>();
idsvrBuilder.AddResourceValidator<CustomResourceValidator>();
```
Run at authorize and token endpoints. Inside, the decorator delegates to `DefaultResourceValidator`, so built-in scope/resource checks still apply. Any v7 implementation must add `CancellationToken` to compile.
