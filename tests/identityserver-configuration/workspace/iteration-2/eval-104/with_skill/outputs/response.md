# Custom Identity Resource with Client Configuration

Here's how to define a custom `employee_info` identity resource with the specified claims, set up an interactive client to request it, and register everything with IdentityServer.

## How Identity Resources Work

An `IdentityResource` is a named group of claims about the user. When a client requests a scope that matches an identity resource, the claims defined in that resource's `UserClaims` collection are included in the identity token and available via the userinfo endpoint.

The `openid` scope is always required by the OpenID Connect specification — it returns the `sub` (subject ID) claim.

## Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        // Required by OIDC spec — returns the "sub" claim
        new IdentityResources.OpenId(),

        // Standard profile claims
        new IdentityResources.Profile(),

        // Custom identity resource for employee information
        new IdentityResource(
            name: "employee_info",
            displayName: "Employee Information",
            userClaims: new[] { "employee_id", "department", "hire_date" })
    })
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("api1", "Main API")
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "interactive.app",
            ClientName = "Interactive Application",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },

            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

            AllowOfflineAccess = true,

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "employee_info",
                "api1"
            }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How It Works

1. The `IdentityResource` named `employee_info` groups three user claims: `employee_id`, `department`, and `hire_date`.
2. The interactive client includes `employee_info` in its `AllowedScopes`, allowing it to request this scope.
3. When the client sends an authorization request with `scope=openid profile employee_info`, IdentityServer will include the `employee_id`, `department`, and `hire_date` claims for the authenticated user.
4. The `openid` scope is always included because it's required by the OIDC specification.

Your identity provider (e.g., ASP.NET Identity profile service) needs to supply these claims for each user — IdentityServer only controls which claims are *allowed* in the token, not their values.
