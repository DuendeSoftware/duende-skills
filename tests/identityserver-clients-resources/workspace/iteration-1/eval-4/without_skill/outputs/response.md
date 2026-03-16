# Custom Identity Resource: employee_info

Here's how to create a custom identity resource for employee information.

## Define the Identity Resource

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResource(
        name: "employee_info",
        userClaims: new[] { "employee_id", "department", "hire_date" })
];
```

## Client Configuration

```csharp
new Client
{
    ClientId = "hr-app",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://hr.example.com/callback" },
    AllowedScopes =
    {
        "openid",
        "profile",
        "employee_info"
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryClients(Config.Clients);
```

## Notes

- The `openid` scope is required for OpenID Connect and must always be included.
- The custom identity resource groups the three employee claims under a single scope name.
- The user's claims store (or profile service) needs to provide these claim values for the authenticated user.
