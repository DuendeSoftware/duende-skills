# Custom DCR validation: authorization_code only, HTTPS redirect URIs, mandatory PKCE

Duende's DCR pipeline exposes a validator you can subclass to add custom rules. Create a class deriving from the base `DynamicClientRegistrationValidator`, enforce your three constraints, and register it in DI so the DCR endpoint uses it.

```csharp
using Duende.IdentityServer.Configuration;

public class CustomDcrValidator : DynamicClientRegistrationValidator
{
    public override async Task<DynamicClientRegistrationValidationResult> ValidateAsync(
        DynamicClientRegistrationContext context)
    {
        var request = context.Request;

        // 1. Only allow authorization_code
        if (request.GrantTypes.Any(gt => gt != "authorization_code"))
        {
            return new DynamicClientRegistrationValidationError(
                "invalid_client_metadata",
                "Only the authorization_code grant type is allowed");
        }

        // 2. All redirect URIs must be HTTPS
        if (request.RedirectUris.Any(uri =>
                !uri.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            return new DynamicClientRegistrationValidationError(
                "invalid_redirect_uri",
                "All redirect URIs must use HTTPS");
        }

        // Run the default validation
        var result = await base.ValidateAsync(context);

        // 3. Force PKCE on the resulting client
        if (result is DynamicClientRegistrationValidatedRequest validated)
        {
            validated.Client.RequirePkce = true;
        }

        return result;
    }
}
```

## Registration

Wire the custom validator into the DI container so it replaces the default:

```csharp
builder.Services.AddIdentityServerConfiguration();

builder.Services
    .AddDynamicClientRegistrationValidator<CustomDcrValidator>();
```

(If that extension isn't available in your version, you can register it directly:
`builder.Services.AddTransient<IDynamicClientRegistrationValidator, CustomDcrValidator>();`)

## What this does

- **Grant types** — any request that includes a grant type other than `authorization_code` is rejected before it can be registered.
- **Redirect URIs** — a plain `https://` prefix check rejects `http://` or other schemes.
- **PKCE** — after the base validation builds the client, we set `RequirePkce = true` so every dynamically registered client must use PKCE.

Adjust the exact error codes/messages to match what your clients expect from the registration endpoint. Check your Duende version's API surface, as some method names and result types differ between releases.
