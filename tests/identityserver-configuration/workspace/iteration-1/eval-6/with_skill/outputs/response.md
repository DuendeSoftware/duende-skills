# Custom Identity Resource with Required Claims

Here's the identity resources configuration including the custom 'organization' resource:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        // Standard OIDC resources
        new IdentityResources.OpenId(),   // Required - returns sub claim
        new IdentityResources.Profile(),  // name, family_name, given_name, etc.

        // Custom identity resource for organization membership
        new IdentityResource(
            name: "organization",
            displayName: "Your organization info",
            userClaims: new[] { "org_id", "org_name", "org_role" })
        {
            Required = true // Not optional on consent screen
        }
    });
```

## How It Works

### Standard Resources

- `IdentityResources.OpenId()` — Mandatory per the OIDC specification. Returns the `sub` (subject ID) claim.
- `IdentityResources.Profile()` — Returns `name`, `family_name`, `given_name`, and other standard profile claims.

### Custom 'organization' Resource

The custom `IdentityResource` with name `"organization"` maps three claims:

| Claim | Purpose |
|-------|---------|
| `org_id` | Organization identifier |
| `org_name` | Organization display name |
| `org_role` | User's role within the organization |

When a client requests the `organization` scope, these claims are included in the identity token (and available from the userinfo endpoint).

### Required = true

Setting `Required = true` means this scope is not shown as an optional checkbox on the consent screen. It's always included when the client requests it. This is appropriate for claims that the application needs to function correctly.

### Client Configuration

Clients that need organization claims must include `"organization"` in their `AllowedScopes`:

```csharp
new Client
{
    ClientId = "admin-app",
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "organization"
    }
}
```

### IProfileService

For the claims to appear in tokens, your `IProfileService` implementation (or ASP.NET Identity integration) must provide the `org_id`, `org_name`, and `org_role` claims for the authenticated user.
