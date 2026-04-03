To customize DCR validation in IdentityServer, you'll need to create a custom validator. Here's an approach:

### Custom Validator

```csharp
using Duende.IdentityServer.Models;

public class CustomDcrValidator
{
    public ValidationResult Validate(DcrRequest request)
    {
        // Only allow authorization_code
        if (request.GrantTypes != null && request.GrantTypes.Any(gt => gt != "authorization_code"))
        {
            return ValidationResult.Error("Only authorization_code grant type is allowed");
        }

        // Enforce HTTPS on redirect URIs
        if (request.RedirectUris != null)
        {
            foreach (var uri in request.RedirectUris)
            {
                if (!uri.StartsWith("https://"))
                {
                    return ValidationResult.Error("Redirect URIs must use HTTPS");
                }
            }
        }

        return ValidationResult.Success;
    }

    public Client CreateClient(DcrRequest request)
    {
        return new Client
        {
            ClientId = Guid.NewGuid().ToString(),
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = request.RedirectUris,
            ClientSecrets = { new Secret(Guid.NewGuid().ToString().Sha256()) }
        };
    }
}
```

### Registration

```csharp
builder.Services.AddSingleton<CustomDcrValidator>();
```

### Usage in the DCR endpoint

```csharp
app.MapPost("/connect/register", async (CustomDcrValidator validator, HttpContext context) =>
{
    var request = await context.Request.ReadFromJsonAsync<DcrRequest>();
    var result = validator.Validate(request);
    if (!result.IsSuccess)
    {
        return Results.BadRequest(new { error = result.ErrorMessage });
    }
    
    var client = validator.CreateClient(request);
    // Store the client...
    
    return Results.Ok(new { client_id = client.ClientId });
}).RequireAuthorization();
```

### Notes
- The validator checks grant types and redirect URIs
- PKCE is set to `true` when creating the client  
- You should also validate other parameters like response types, token endpoint auth method, etc.
- Consider using an interface so you can easily swap implementations
