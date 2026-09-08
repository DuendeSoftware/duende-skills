# Custom DCR validator: authorization_code only, HTTPS redirect URIs, PKCE required

Extend `DynamicClientRegistrationValidator` and override the relevant validation steps. Each override enforces one rule, calling `context.SetError(...)` to reject and returning `base.XxxAsync(context)` to continue the default pipeline when the rule passes. PKCE is enforced as a default in `SetClientDefaultsAsync`.

## The validator

```csharp
using Duende.IdentityServer.Configuration.Validation.DynamicClientRegistration;

public class HardenedDcrValidator : DynamicClientRegistrationValidator
{
    // 1. Only allow the authorization_code grant type
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        var grantTypes = context.Request.GrantTypes;
        if (grantTypes.Any(gt => gt != "authorization_code"))
        {
            context.SetError("Only the authorization_code grant type is permitted");
            return Task.CompletedTask;
        }

        return base.ValidateGrantTypesAsync(context);
    }

    // 2. All redirect URIs must be HTTPS
    protected override Task ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        var uris = context.Request.RedirectUris;
        if (uris.Any(u => !u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            context.SetError("All redirect URIs must use HTTPS");
            return Task.CompletedTask;
        }

        return base.ValidateRedirectUrisAsync(context);
    }

    // 3. Always require PKCE for dynamically registered clients
    protected override Task SetClientDefaultsAsync(
        DynamicClientRegistrationContext context)
    {
        context.Client.RequirePkce = true;

        return base.SetClientDefaultsAsync(context);
    }
}
```

## Registration

Register the validator on the configuration builder returned by `AddIdentityServerConfiguration()`:

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<HardenedDcrValidator>();
```

## Notes

- **`ValidateGrantTypesAsync`** — rejects the request if any requested grant type is not `authorization_code`. Only when the check passes do we call the base implementation to keep IdentityServer's built-in validation.
- **`ValidateRedirectUrisAsync`** — a case-insensitive `https://` prefix check rejects any non-HTTPS redirect URI.
- **`SetClientDefaultsAsync`** — sets `context.Client.RequirePkce = true` so every registered client requires PKCE regardless of what was requested. You can harden further here (e.g. `client.AllowOfflineAccess = false`, shorter `AccessTokenLifetime`).
- Each override calls `context.SetError(...)` and returns early on failure, otherwise defers to `base.XxxAsync(context)`.

This gives you a single validator enforcing all three rules, wired in with `AddDynamicClientRegistrationValidator<T>()`.
