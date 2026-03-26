# Custom DCR Validator

```csharp
public class CustomDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        if (context.Request.GrantTypes.Any(g => g != "authorization_code"))
        {
            context.SetError("Only authorization_code allowed");
            return Task.CompletedTask;
        }
        return base.ValidateGrantTypesAsync(context);
    }

    protected override Task ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        if (context.Request.RedirectUris.Any(u => !u.StartsWith("https://")))
        {
            context.SetError("HTTPS required for redirect URIs");
            return Task.CompletedTask;
        }
        return base.ValidateRedirectUrisAsync(context);
    }

    protected override Task SetClientDefaultsAsync(
        DynamicClientRegistrationContext context)
    {
        context.Client.RequirePkce = true;
        return base.SetClientDefaultsAsync(context);
    }
}
```

Register it:

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<CustomDcrValidator>();
```
