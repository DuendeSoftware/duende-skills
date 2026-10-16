# Per-sign-in metadata for the session viewer

Put the metadata in `AuthenticationProperties.Items` of the `AuthenticationTicket`. With server-side sessions the ticket is stored in the session store; it stays inside IdentityServer and is **not issued as claims**.

## Writing it

Plain `HttpContext.SignInAsync`:

```csharp
var properties = new AuthenticationProperties();
properties.Items["device_name"] = "Bob's iPhone";
properties.Items["region"] = "eu-west";

await HttpContext.SignInAsync(identityServerUser, properties);
```

ASP.NET Identity:

```csharp
await _signInManager.SignInWithClaimsAsync(user, properties, additionalClaims: []);
```

`PasswordSignInAsync` does not accept `AuthenticationProperties`. If you use it, override `SignInWithClaimsAsync` in a custom `SignInManager<TUser>` to inject the metadata:

```csharp
public class MetadataSignInManager<TUser> : SignInManager<TUser> where TUser : class
{
    // ctor omitted
    public override Task SignInWithClaimsAsync(TUser user, AuthenticationProperties? props, IEnumerable<Claim> extra)
    {
        props ??= new AuthenticationProperties();
        props.Items["device_name"] = /* from request */ "";
        props.Items["region"] = "";
        return base.SignInWithClaimsAsync(user, props, extra);
    }
}
```

## Reading it back

```csharp
var sessions = await _sessionManagementService.QuerySessionsAsync(new SessionQuery { SubjectId = "12345" });

foreach (var session in sessions.Results)
{
    if (session.AuthenticationTicket.Properties.Items.TryGetValue("device_name", out var deviceName))
    {
        // show deviceName
    }
}
```

## Limitations
- Custom metadata is **not indexed** by the built-in store: you cannot filter `SessionQuery` by it. Query by subject id, session id or display name first, then inspect the tickets in memory.
- Only the three indices (subject, session id, display name) exist; `DisplayName` needs `UserDisplayNameClaimType` set.
- Keep the values small and non-secret; the ticket is protected by Data Protection (share keys across instances).
