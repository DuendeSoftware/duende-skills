# Custom DCR Validator: Authorization Code Only, HTTPS Redirect URIs, PKCE Required

You need to extend `DynamicClientRegistrationValidator` to enforce these rules and register it with `AddDynamicClientRegistrationValidator<T>()`.

## Custom Validator

```csharp
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Configuration.Models;

public class StrictDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        var grantTypes = context.Request.GrantTypes;

        // Only allow authorization_code grant type
        if (grantTypes == null || grantTypes.Count == 0)
        {
            // Default to authorization_code if not specified
            context.Client.AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code;
            return base.ValidateGrantTypesAsync(context);
        }

        if (grantTypes.Any(gt => gt != "authorization_code"))
        {
            context.SetError("Only the authorization_code grant type is allowed for dynamically registered clients.");
            return Task.CompletedTask;
        }

        return base.ValidateGrantTypesAsync(context);
    }

    protected override Task ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        var uris = context.Request.RedirectUris;

        if (uris == null || !uris.Any())
        {
            context.SetError("At least one redirect URI is required.");
            return Task.CompletedTask;
        }

        // Enforce HTTPS on all redirect URIs
        if (uris.Any(u => !u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            context.SetError("All redirect URIs must use HTTPS.");
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

        // Additional security defaults
        client.AllowOfflineAccess = false;
        client.AccessTokenLifetime = 300; // 5 minutes
        client.RequireClientSecret = true;

        return base.SetClientDefaultsAsync(context);
    }
}
```

## Registration in Program.cs

```csharp
// Add DCR configuration services with the custom validator
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<StrictDcrValidator>();
```

## How It Works

1. **`ValidateGrantTypesAsync`** — Checks that only `authorization_code` is requested. If any other grant type (e.g., `client_credentials`, `implicit`) is requested, the registration is rejected with an error via `context.SetError()`.

2. **`ValidateRedirectUrisAsync`** — Ensures all redirect URIs use HTTPS. Non-HTTPS URIs are rejected. This prevents redirect attacks using unencrypted channels.

3. **`SetClientDefaultsAsync`** — Sets `RequirePkce = true` on all dynamically registered clients, ensuring they must use PKCE for authorization code flows. Also sets conservative defaults like short token lifetimes and no offline access.

Each override calls `base.ValidateXxxAsync()` at the end on success to allow the default validation pipeline to continue processing.
