# Custom `organization` Identity Resource

Define the custom `organization` identity resource alongside the standard `openid` and `profile` resources. Marking it `Required = true` means it is always included and is not shown as an optional toggle on the consent screen.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),   // required — maps to "sub"
            new IdentityResources.Profile(),  // name, family_name, given_name, etc.

            new IdentityResource(
                name: "organization",
                displayName: "Organization information",
                userClaims: new[] { "org_id", "org_name", "org_role" })
            {
                Required = true // always granted; not shown as optional on consent
            }
        };
}
```

Register it with IdentityServer:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

## Notes

- **`new IdentityResources.OpenId()`** and **`new IdentityResources.Profile()`** are the standard built-in resources; `openid` is mandatory for any OpenID Connect request (it returns the `sub` claim).
- The **custom `organization` resource** groups the three user claims `org_id`, `org_name`, and `org_role`. When a client is granted the `organization` scope, these claims flow into the identity token / userinfo endpoint.
- **`Required = true`** forces the resource to be included whenever the client requests it and prevents it from being displayed as an optional, user-deselectable item on the consent screen.
- For the claims to actually appear, your `IProfileService` (or the underlying user store) must be able to emit `org_id`, `org_name`, and `org_role` for the user.
