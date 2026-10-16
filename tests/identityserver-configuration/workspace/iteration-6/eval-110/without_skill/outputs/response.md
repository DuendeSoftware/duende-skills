```csharp
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;

public class CustomResourceValidator : IResourceValidator
{
    private readonly IResourceValidator _inner;
    public CustomResourceValidator(IResourceValidator inner) => _inner = inner;

    public async Task<ResourceValidationResult> ValidateRequestedResourcesAsync(ResourceValidationRequest request)
    {
        var result = await _inner.ValidateRequestedResourcesAsync(request);
        if (result.Succeeded && result.Resources.ApiScopes.Any(s => s.Name == "forbidden"))
        {
            return new ResourceValidationResult();   // invalid
        }
        return result;
    }
}
```
Registration (decorating the default):
```csharp
builder.Services.AddIdentityServer()...;
builder.Services.AddTransient<IResourceValidator, CustomResourceValidator>(); // wrong; see below
```
Using `AddResourceValidator<T>` would replace it. To wrap: register the default concrete type, then the decorator:
```csharp
builder.Services.AddTransient<DefaultResourceValidator>();
builder.Services.AddTransient<IResourceValidator>(sp =>
    new CustomResourceValidator(sp.GetRequiredService<DefaultResourceValidator>()));
```
Register after `AddIdentityServer()` so yours wins. Note I'm not certain of every v8 member name; check the signature against the IntelliSense of your installed version.
