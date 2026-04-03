Here's a custom DCR validator that restricts grant types to `authorization_code`, enforces HTTPS on all redirect URIs, and requires PKCE.

### CustomDcrValidator.cs

```csharp
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Configuration.Models;

public class CustomDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        var grantTypes = context.Request.GrantTypes;

        // Only allow authorization_code grant type
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

        // Always require PKCE for dynamically registered clients
        client.RequirePkce = true;

        // Additional security defaults
        client.AllowOfflineAccess = false;
        client.AccessTokenLifetime = 300; // 5 minutes

        return base.SetClientDefaultsAsync(context);
    }
}
```

### Register the validator in Program.cs

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<CustomDcrValidator>();
```

### How it works

1. **`ValidateGrantTypesAsync`** — Checks each requested grant type against the allowlist. If any grant type other than `authorization_code` is requested, it calls `context.SetError()` to reject the request with a descriptive error message.

2. **`ValidateRedirectUrisAsync`** — Iterates over all requested redirect URIs and rejects any that don't use HTTPS. This prevents insecure redirects.

3. **`SetClientDefaultsAsync`** — Sets `RequirePkce = true` on every dynamically registered client, ensuring that PKCE is always enforced regardless of what the caller requests.

Each method calls `base.{method}()` after custom validation to preserve the built-in validation logic from `DynamicClientRegistrationValidator`.
