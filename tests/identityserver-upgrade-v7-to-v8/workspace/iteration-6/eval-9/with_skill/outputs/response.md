# `IProfileService` in v8: `Client` → `Application`

Both `ProfileDataRequestContext` and `IsActiveContext` **replaced `Client Client`** with **`IConnectedApplication? Application`**. v8 can serve SAML service providers, so the caller may not be an OIDC client. This is why your code, which compiled on v7, no longer builds.

`Client` and `SamlServiceProvider` both implement `IConnectedApplication`, which exposes `Identifier` (client ID for OIDC, entity ID for SAML), `DisplayName` and `Enabled`.

## Changes
```csharp
public async Task GetProfileDataAsync(ProfileDataRequestContext context, CancellationToken ct)
{
    // ❌ v7: context.Client.ClientId
    var appId = context.Application?.Identifier;

    if (context.Application is Client client)
    {
        // OIDC-specific: client.Properties, client.AllowedGrantTypes ...
    }
    else if (context.Application is SamlServiceProvider sp)
    {
        // SAML: e.g. different claims for the service provider
    }
    ...
}

public async Task IsActiveAsync(IsActiveContext context, CancellationToken ct)
{
    var appId = context.Application?.Identifier;

    if (context.Caller == IdentityServerConstants.ProfileIsActiveCallers.SamlSsoEndpoint)
    {
        // new case: called from the SAML SSO endpoint
    }
    context.IsActive = await _users.IsActiveAsync(context.Subject.GetSubjectId(), ct);
}
```
Also note `IProfileService` methods now take a `CancellationToken ct`.

## The new runtime case
**Your profile service may now be invoked for SAML requests.**
- Don't cast `Application` to `Client` unchecked. Use pattern matching (`is Client client`).
- `Application` is nullable, so handle `null`.
- In `IsActiveAsync`, SAML calls have `context.Caller == IdentityServerConstants.ProfileIsActiveCallers.SamlSsoEndpoint`.
