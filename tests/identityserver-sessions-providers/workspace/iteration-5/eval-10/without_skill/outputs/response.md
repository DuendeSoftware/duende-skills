# Storing Per-Sign-In Metadata in the Session

You can attach metadata such as device name and region to the authentication session using `AuthenticationProperties.Items`. This data is carried inside the authentication ticket and is **not** emitted as claims, so it never ends up in tokens or userinfo — it's purely for your own server-side use (e.g. an admin session viewer).

## Writing metadata at sign-in

### Plain `HttpContext.SignInAsync`

```csharp
using Microsoft.AspNetCore.Authentication;

var properties = new AuthenticationProperties();
properties.Items["device_name"] = "Alice's iPhone";
properties.Items["region"] = "eu-west";

await HttpContext.SignInAsync(user, properties);
```

### ASP.NET Core Identity

`SignInManager` has `SignInWithClaimsAsync`, which takes `AuthenticationProperties`:

```csharp
var properties = new AuthenticationProperties();
properties.Items["device_name"] = "Alice's iPhone";
properties.Items["region"] = "eu-west";

await _signInManager.SignInWithClaimsAsync(user, properties, additionalClaims: []);
```

## Reading metadata back

Use `ISessionManagementService` to query sessions, then read the stored items from the ticket's properties:

```csharp
var sessions = await _sessionManagementService.QuerySessionsAsync(new SessionQuery
{
    SubjectId = "88421113"
});

foreach (var session in sessions.Results)
{
    if (session.AuthenticationTicket.Properties.Items.TryGetValue("device_name", out var device))
    {
        // display device in the admin viewer
    }
}
```

## Notes

- The metadata is stored in `AuthenticationProperties.Items`, which is part of the authentication ticket — it is **not** issued as claims.
- Keep the values small; the ticket is serialized and stored with the session.
- This approach works well for an admin session viewer that lists a user's active sessions and shows the device/region captured at sign-in.
