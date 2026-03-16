Here's how to define a custom `organization` identity resource alongside the standard `openid` and `profile` resources:

```csharp
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
        // Standard identity resources
        new IdentityResources.OpenId(),   // Required — maps to "sub" claim
        new IdentityResources.Profile(),  // name, family_name, given_name, etc.

        // Custom identity resource for organization membership
        new IdentityResource(
            name: "organization",
            displayName: "Your organization info",
            userClaims: new[] { "org_id", "org_name", "org_role" })
        {
            Required = true  // Not optional on consent screen
        }
    })
    .AddInMemoryApiScopes(Array.Empty<ApiScope>())
    .AddInMemoryClients(Array.Empty<Client>());

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### How It Works

1. **`new IdentityResources.OpenId()`** — The mandatory identity resource for any OpenID Connect request. Maps to the `sub` (subject ID) claim.

2. **`new IdentityResources.Profile()`** — Standard profile claims (`name`, `family_name`, `given_name`, etc.).

3. **Custom `organization` resource** — Created using the `IdentityResource` constructor that takes a name, display name, and array of user claim types. When a client requests the `organization` scope:
   - The `org_id`, `org_name`, and `org_role` claims are included in the identity token (and available from the userinfo endpoint)
   - These claims must be populated by your `IProfileService` implementation

4. **`Required = true`** — Marks this resource as required on the consent screen. Instead of being shown as an optional checkbox the user can uncheck, it's always included when the client requests it. This is appropriate for claims that are fundamental to the application's operation.

### Using It in a Client

Clients that need organization info add `"organization"` to their `AllowedScopes`:

```csharp
new Client
{
    ClientId = "admin-portal",
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "organization"
    }
}
```
