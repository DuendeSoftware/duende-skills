# Per-sign-in metadata for the session viewer

Store it in `AuthenticationProperties.Items`. Items go into the session ticket (the server-side session store) and are not emitted as claims in tokens.

## Plain sign-in

```csharp
var props = new AuthenticationProperties();
props.Items["device_name"] = deviceName;
props.Items["region"] = region;

var isuser = new IdentityServerUser(subjectId) { DisplayName = name };
await HttpContext.SignInAsync(isuser, props);
```

## ASP.NET Identity

```csharp
var props = new AuthenticationProperties();
props.Items["device_name"] = deviceName;
props.Items["region"] = region;

await _signInManager.SignInAsync(user, props);
// or: _signInManager.PasswordSignInAsync(...) after setting props via a custom SignInManager
```

For `PasswordSignInAsync` there is no props overload, so call `CheckPasswordSignInAsync` and then `SignInAsync(user, props)`, or `SignInWithClaimsAsync(user, props, extraClaims)`.

## Reading back

```csharp
var result = await sessions.QuerySessionsAsync(new SessionQuery { SubjectId = id, CountRequested = 20 });
foreach (var s in result.Results)
{
    s.Ticket.Properties.Items.TryGetValue("device_name", out var device);
    s.Ticket.Properties.Items.TryGetValue("region", out var region);
}
```

## Limitations
- You cannot filter/query by these values: only SubjectId, SessionId and DisplayName are indexed.
- Values live inside the serialized ticket, so keep them small and non-sensitive; they're set at sign-in time only and require re-sign-in/renewal to change.
- Requires server-side sessions.
