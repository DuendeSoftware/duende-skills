```csharp
using Duende.IdentityServer.Models;

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource("employee_info", "Employee information",
            new[] { "employee_id", "department", "hire_date" })
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "interactive",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "employee_info" }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```
The claims only appear if your `IProfileService` (or user store) supplies `employee_id`, `department`, `hire_date`. The client must request `scope=employee_info`; claims go in the ID token or userinfo depending on `AlwaysIncludeUserClaimsInIdToken`.
