# Custom DCR validator: authorization_code only, HTTPS redirects, PKCE always

Extend `DynamicClientRegistrationValidator` and override the relevant steps. `DynamicClientRegistrationContext` provides `Client`, `Request`, `Caller` and `Items`.

```csharp
using Duende.IdentityServer.Configuration;

public class StrictDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(DynamicClientRegistrationContext context)
    {
        // Only allow authorization_code
        var grantTypes = context.Request.GrantTypes;
        if (grantTypes.Count == 0 || grantTypes.Any(gt => gt != "authorization_code"))
        {
            context.SetError("Only the authorization_code grant type is allowed");
            return Task.CompletedTask;
        }

        return base.ValidateGrantTypesAsync(context);
    }

    protected override Task ValidateRedirectUrisAsync(DynamicClientRegistrationContext context)
    {
        // Enforce HTTPS redirect URIs
        var uris = context.Request.RedirectUris;
        if (uris.Count == 0 ||
            uris.Any(u => !u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            context.SetError("Redirect URIs must use HTTPS");
            return Task.CompletedTask;
        }

        return base.ValidateRedirectUrisAsync(context);
    }

    protected override Task SetClientDefaultsAsync(DynamicClientRegistrationContext context)
    {
        var client = context.Client;
        client.RequirePkce = true;            // always
        client.AllowOfflineAccess = false;
        client.AccessTokenLifetime = 300;     // 5 minutes

        return base.SetClientDefaultsAsync(context);
    }
}
```

Register it:
```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<StrictDcrValidator>();
```

Notes:
- Validation methods call `context.SetError(...)` and return early so the request is rejected; otherwise they delegate to `base` to keep default validation.
- Setting `RequirePkce` in `SetClientDefaultsAsync` ensures it is applied regardless of what the caller sends.
- Consider also constraining scopes (no admin scopes, `offline_access` off) since dynamically registered clients are untrusted input.
- Combine with an authorization policy on `/connect/dcr`, and use a persistent store in production.
