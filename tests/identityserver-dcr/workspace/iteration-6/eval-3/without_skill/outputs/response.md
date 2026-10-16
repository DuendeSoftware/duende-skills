# Custom DCR validator

Derive from `DynamicClientRegistrationValidator` and override the step methods.

```csharp
using Duende.IdentityServer.Configuration.Models.DynamicClientRegistration;
using Duende.IdentityServer.Configuration.Validation.DynamicClientRegistration;

public class StrictDcrValidator : DynamicClientRegistrationValidator
{
    public StrictDcrValidator(/* base ctor deps */) : base(/* ... */) { }

    protected override Task<(Client, DynamicClientRegistrationError?)> ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        var types = context.Request.GrantTypes;
        if (types is null || types.Count != 1 || types.First() != "authorization_code")
            return Task.FromResult<(Client, DynamicClientRegistrationError?)>((context.Client,
                new DynamicClientRegistrationError("invalid_client_metadata",
                    "Only authorization_code grant type is allowed")));

        context.Client.AllowedGrantTypes = { "authorization_code" };
        return Task.FromResult<(Client, DynamicClientRegistrationError?)>((context.Client, null));
    }

    protected override Task<(Client, DynamicClientRegistrationError?)> ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        var uris = context.Request.RedirectUris;
        if (uris is null || uris.Count == 0 || uris.Any(u => u.Scheme != Uri.UriSchemeHttps))
            return Task.FromResult<(Client, DynamicClientRegistrationError?)>((context.Client,
                new DynamicClientRegistrationError("invalid_redirect_uri", "All redirect URIs must use HTTPS")));

        foreach (var u in uris) context.Client.RedirectUris.Add(u.ToString());
        return Task.FromResult<(Client, DynamicClientRegistrationError?)>((context.Client, null));
    }

    protected override async Task<(Client, DynamicClientRegistrationError?)> SetClientDefaultsAsync(
        DynamicClientRegistrationContext context)
    {
        var r = await base.SetClientDefaultsAsync(context);
        context.Client.RequirePkce = true;   // always
        return r;
    }
}
```

Register it after `AddIdentityServerConfiguration` so yours wins:
```csharp
builder.Services.AddIdentityServerConfiguration();
builder.Services.AddTransient<IDynamicClientRegistrationValidator, StrictDcrValidator>();
```
Exact base-method names and signatures can vary by version; check `DynamicClientRegistrationValidator` in your IDE and adjust.
