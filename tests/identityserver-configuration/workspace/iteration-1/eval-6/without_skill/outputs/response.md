Here's how to define the custom identity resource alongside the standard ones:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),

        new IdentityResource(
            name: "organization",
            displayName: "Organization Info",
            userClaims: new[] { "org_id", "org_name", "org_role" })
        {
            Required = true
        }
    })
    .AddInMemoryClients(new List<Client>());

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This defines:
- The standard `openid` resource (required for OIDC, maps to `sub` claim)
- The standard `profile` resource (name, family_name, etc.)
- A custom `organization` resource with three claims (`org_id`, `org_name`, `org_role`) marked as `Required = true` so it won't be shown as optional on the consent screen

When a client requests the `organization` scope, the specified claims will be included in the identity token. You'll need to implement an `IProfileService` to populate these claims from your user store.
