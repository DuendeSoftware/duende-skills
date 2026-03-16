# Custom Identity Resource: employee_info

Here's how to define a custom identity resource called `employee_info` with custom claims, and configure a client to request it.

## 1. Define the Custom Identity Resource

An **IdentityResource** is a named group of claims about a user, requested via the `scope` parameter. The `openid` scope is mandatory per the OpenID Connect spec.

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    // Required by OIDC spec — returns the 'sub' claim
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),

    // Custom identity resource for employee information
    new IdentityResource(
        name: "employee_info",
        displayName: "Employee Information",
        userClaims: new[] { "employee_id", "department", "hire_date" })
];
```

## 2. Configure the Client

An interactive client that needs to access `employee_info` must include it in `AllowedScopes` alongside the mandatory `openid` scope:

```csharp
new Client
{
    ClientId = "hr-portal",
    ClientName = "HR Portal",

    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    ClientSecrets = { new Secret(configuration["HrPortal:Secret"].Sha256()) },

    RedirectUris = { "https://hr.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://hr.example.com/signout-callback-oidc" },

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "employee_info"  // Request the custom identity resource
    }
}
```

## 3. Registration in Program.cs

Register the identity resources with `AddInMemoryIdentityResources`:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddTestUsers(TestUsers.Users);
```

## How It Works

When the client requests the `employee_info` scope:

```
GET /connect/authorize?client_id=hr-portal&scope=openid profile employee_info&...
```

IdentityServer will include the `employee_id`, `department`, and `hire_date` claims in the identity token (or make them available via the userinfo endpoint, depending on `AlwaysIncludeUserClaimsInIdToken`).

The claims must be populated by your `IProfileService` implementation or test user claims. For example:

```csharp
new Duende.IdentityServer.Test.TestUser
{
    SubjectId = "1",
    Username = "alice",
    Password = "password",
    Claims =
    {
        new Claim("name", "Alice Smith"),
        new Claim("employee_id", "EMP-12345"),
        new Claim("department", "Engineering"),
        new Claim("hire_date", "2023-01-15"),
    }
}
```

## Key Points

- **`IdentityResources.OpenId()` is always required** — it maps to the `sub` claim and is mandatory per the OIDC spec. Without it, OpenID Connect requests will fail.
- Custom identity resources group user claims under a named scope, making them requestable by clients.
- If a client requests a scope without a matching `IdentityResource` registered on the server, the request will fail or return no claims.
