# Custom DCR Validator for Duende IdentityServer

To customize the DCR validation, you'll need to create a custom validator that extends the built-in validation logic.

## Custom Validator Implementation

```csharp
using Duende.IdentityServer.Configuration;

public class StrictDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        var grantTypes = context.Request.GrantTypes;

        // Only allow authorization_code
        if (grantTypes != null && grantTypes.Any(gt => gt != "authorization_code"))
        {
            context.SetError("Only authorization_code grant type is permitted.");
            return Task.CompletedTask;
        }

        return base.ValidateGrantTypesAsync(context);
    }

    protected override Task ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        var uris = context.Request.RedirectUris;

        if (uris != null && uris.Any(u => !u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            context.SetError("All redirect URIs must use HTTPS.");
            return Task.CompletedTask;
        }

        return base.ValidateRedirectUrisAsync(context);
    }

    protected override Task SetClientDefaultsAsync(
        DynamicClientRegistrationContext context)
    {
        context.Client.RequirePkce = true;
        context.Client.AllowOfflineAccess = false;

        return base.SetClientDefaultsAsync(context);
    }
}
```

## Registration

Register the custom validator in your DI container:

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<StrictDcrValidator>();
```

## What This Does

- **Grant type restriction**: Only `authorization_code` is allowed. Any request specifying other grant types (like `client_credentials` or `implicit`) is rejected.
- **HTTPS enforcement**: All redirect URIs must use HTTPS. HTTP redirect URIs are rejected.
- **PKCE requirement**: Sets `RequirePkce = true` on all dynamically registered clients, ensuring PKCE is mandatory for auth code flows.
