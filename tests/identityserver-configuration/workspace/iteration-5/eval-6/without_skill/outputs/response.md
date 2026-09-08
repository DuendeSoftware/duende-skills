# Custom `organization` Identity Resource

Here's how to define a custom identity resource named `organization` that carries the `org_id`, `org_name`, and `org_role` claims, alongside the standard `openid` and `profile` resources. Setting `Required = true` makes it non-optional on the consent screen.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),
            new IdentityResources.Profile(),

            new IdentityResource(
                name: "organization",
                displayName: "Organization info",
                userClaims: new[] { "org_id", "org_name", "org_role" })
            {
                Required = true
            }
        };
}
```

Register with:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

## Notes

- `IdentityResources.OpenId()` is required by OIDC and returns `sub`; `Profile()` adds the standard profile claims.
- The custom `organization` resource bundles `org_id`, `org_name`, and `org_role`. When a client requests the `organization` scope, these claims are emitted into the identity token/userinfo.
- `Required = true` means the resource is always included and shown as required (not an optional checkbox) during consent.
- Make sure your user store or profile service can produce those three claim values.
