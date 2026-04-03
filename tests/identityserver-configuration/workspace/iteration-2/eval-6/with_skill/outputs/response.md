Here's the identity resource configuration with the custom `organization` resource:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),

        // Custom identity resource for organization membership
        new IdentityResource(
            name: "organization",
            displayName: "Your organization info",
            userClaims: new[] { "org_id", "org_name", "org_role" })
        {
            Required = true // Not shown as optional on the consent screen
        }
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key points:**

- `new IdentityResources.OpenId()` registers the mandatory `openid` scope (maps to the `sub` claim).
- `new IdentityResources.Profile()` registers the standard `profile` scope (name, family_name, etc.).
- The custom `IdentityResource` with name `"organization"` defines three user claims: `org_id`, `org_name`, and `org_role`. When a client requests the `organization` scope, these claims will be included in the identity token and/or available via the userinfo endpoint.
- `Required = true` means this resource is not shown as optional on the consent screen — if the client requests it, the user cannot deselect it.
