# Per-Sign-In Session Metadata (Not Claims)

Store admin-only data like device name and region inside the session's `AuthenticationTicket` via `AuthenticationProperties.Items`. It lives inside IdentityServer's server-side session and is **never issued as claims** to clients or tokens.

## Writing metadata at sign-in

### Plain `HttpContext.SignInAsync`

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.Authentication;

var user = new IdentityServerUser("88421113")
{
    DisplayName = "Alice"
}.CreatePrincipal();

var properties = new AuthenticationProperties();
properties.Items["device_name"] = "Alice's iPhone 15";
properties.Items["region"] = "eu-west";

// The Items ride along in the AuthenticationTicket -> stored server-side, not as claims
await HttpContext.SignInAsync(user, properties);
```

### ASP.NET Core Identity path

`SignInManager.SignInWithClaimsAsync` accepts `AuthenticationProperties`, so pass the metadata there (additional claims left empty since this is not claim data):

```csharp
var properties = new AuthenticationProperties();
properties.Items["device_name"] = "Alice's iPhone 15";
properties.Items["region"] = "eu-west";

await _signInManager.SignInWithClaimsAsync(user, properties, additionalClaims: []);
```

**Caveat:** if you sign users in with `PasswordSignInAsync` (which does **not** accept `AuthenticationProperties`), you can't attach the metadata directly. Subclass `SignInManager<TUser>` and **override `SignInWithClaimsAsync`** to inject the metadata there, so it's captured on the password flow too:

```csharp
public class MetadataSignInManager : SignInManager<ApplicationUser>
{
    // ... ctor forwarding ...
    public override async Task SignInWithClaimsAsync(
        ApplicationUser user, AuthenticationProperties? props, IEnumerable<Claim> additionalClaims)
    {
        props ??= new AuthenticationProperties();
        props.Items["device_name"] = _http.HttpContext?.Request.Headers.UserAgent.ToString();
        props.Items["region"] = ResolveRegion();
        await base.SignInWithClaimsAsync(user, props, additionalClaims);
    }
}
// builder.Services.AddScoped<SignInManager<ApplicationUser>, MetadataSignInManager>();
```

## Reading metadata back

Query sessions with `ISessionManagementService`, then read the values from `AuthenticationTicket.Properties.Items`:

```csharp
var sessions = await _sessionManagementService.QuerySessionsAsync(new SessionQuery
{
    SubjectId = "88421113"
});

foreach (var session in sessions.Results)
{
    if (session.AuthenticationTicket.Properties.Items
            .TryGetValue("device_name", out var deviceName))
    {
        // show deviceName in the admin session viewer
    }
    session.AuthenticationTicket.Properties.Items
        .TryGetValue("region", out var region);
}
```

## Query limitation

This metadata is **not issued as claims** and is **not indexed** by the session store. The only indexed/queryable fields are **SubjectId (`sub`)**, **SessionId (`sid`)**, and the configurable **DisplayName**. That means you **cannot filter `SessionQuery` by `device_name` or `region`**.

Pattern: query by subject id, session id, or display name first, then **inspect the returned tickets** (`Properties.Items`) in memory to read/filter on the custom metadata.
