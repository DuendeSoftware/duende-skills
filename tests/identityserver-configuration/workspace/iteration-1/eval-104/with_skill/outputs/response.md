# Custom Identity Resource: employee_info

Here's the full configuration with the custom identity resource, client setup, and registration:

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
        // Required by OIDC spec
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),

        // Custom identity resource for employee information
        new IdentityResource(
            name: "employee_info",
            displayName: "Employee Information",
            userClaims: new[] { "employee_id", "department", "hire_date" })
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "hr-portal",
            ClientName = "HR Portal",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },

            RedirectUris = { "https://hr.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://hr.example.com/signout-callback-oidc" },

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "employee_info"  // Request the custom identity resource
            }
        }
    });
```

## How It Works

### Custom Identity Resource

The `IdentityResource` with name `"employee_info"` defines three user claims:

| Claim | Description |
|-------|-------------|
| `employee_id` | Unique employee identifier |
| `department` | Employee's department |
| `hire_date` | Date the employee was hired |

When a client requests the `employee_info` scope, these claims are included in the identity token and available from the userinfo endpoint.

### Client Scope Registration

The client must include `"employee_info"` in its `AllowedScopes` to be permitted to request this scope. The `openid` scope is always required for OIDC.

### IProfileService

For these claims to appear in tokens, your user store must provide them. If using ASP.NET Identity, add them as claims on the user. If using a custom `IProfileService`, return them in `GetProfileDataAsync`:

```csharp
public class ProfileService : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        if (context.RequestedClaimTypes.Contains("employee_id"))
        {
            var user = await _userStore.FindBySubjectId(context.Subject.GetSubjectId());
            context.IssuedClaims.Add(new Claim("employee_id", user.EmployeeId));
            context.IssuedClaims.Add(new Claim("department", user.Department));
            context.IssuedClaims.Add(new Claim("hire_date", user.HireDate.ToString("O")));
        }
    }
}
```
