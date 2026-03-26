# Custom DCR Validator

Here's a custom validator that restricts grant types, enforces HTTPS redirects, and requires PKCE:

```csharp
public class StrictDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        var grantTypes = context.Request.GrantTypes;

        // Only allow authorization_code
        if (grantTypes.Any(gt => gt != "authorization_code"))
        {
            context.SetError("Only authorization_code grant type is allowed");
            return Task.CompletedTask;
        }

        return base.ValidateGrantTypesAsync(context);
    }

    protected override Task ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        var uris = context.Request.RedirectUris;

        // Enforce HTTPS on all redirect URIs
        if (uris.Any(u => !u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            context.SetError("All redirect URIs must use HTTPS");
            return Task.CompletedTask;
        }

        return base.ValidateRedirectUrisAsync(context);
    }

    protected override Task SetClientDefaultsAsync(
        DynamicClientRegistrationContext context)
    {
        var client = context.Client;

        // Always require PKCE
        client.RequirePkce = true;
        client.AllowPlainTextPkce = false;

        // Secure defaults
        client.AllowOfflineAccess = false;
        client.AccessTokenLifetime = 300; // 5 minutes

        return base.SetClientDefaultsAsync(context);
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<StrictDcrValidator>();
```

## How the Validation Pipeline Works

The `DynamicClientRegistrationValidator` has a pipeline of overridable methods:

1. `ValidateGrantTypesAsync` - Validates allowed grant types
2. `ValidateRedirectUrisAsync` - Validates redirect URI format and restrictions
3. `ValidateSoftwareStatementAsync` - Validates software statements (if present)
4. `SetClientDefaultsAsync` - Sets defaults on the `Client` object after validation

Each method receives a `DynamicClientRegistrationContext` with:
- `context.Request` - The raw DCR request
- `context.Client` - The IdentityServer `Client` being built
- `context.Caller` - The authenticated caller's `ClaimsPrincipal`

Call `context.SetError("message")` to reject the request. Always call `base.*Async(context)` at the end for successful paths to let the base class continue its validation.
