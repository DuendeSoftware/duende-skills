# Claims Integration with Duende User Management

## How Claims Delivery Works

When you call `AddUserManagement()` on the IdentityServer builder, it **automatically registers an `IProfileService`** implementation. This means you don't need to manually implement or register a profile service — User Management handles claims delivery out of the box.

## Claims Mapping Based on Scopes

User profile attributes are automatically mapped to token claims based on the scopes requested by the client:

| Scope | Claims |
|-------|--------|
| `openid` | `sub` (subject identifier) |
| `profile` | `name`, `given_name`, `family_name`, `nickname`, etc. |
| `email` | `email`, `email_verified` |

## Setup

Ensure your IdentityServer options have `LoginUrl` and `LogoutUrl` configured to point to your account pages:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        options.AddSqliteStore("Data Source=users.db");
        options.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp));
    });
```

Your client already requests the `email` scope:

```csharp
AllowedScopes = { "openid", "profile", "email", "api1" }
```

This means the `email` and `email_verified` claims will automatically appear in ID tokens for this client.

## Custom Profile Attributes

For custom user attributes (beyond the standard OIDC claims), you can expose them through **custom identity resources**:

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email(),
    new IdentityResource("custom_profile", new[] { "department", "employee_id" })
];
```

Custom attributes stored in the user's profile (as key-value pairs) will be mapped to claims when the corresponding identity resource is requested.

## Summary

- `AddUserManagement()` automatically registers `IProfileService` — no manual implementation needed.
- Standard claims (sub, email, name) are mapped based on requested scopes.
- Custom attributes require a custom identity resource to be exposed in tokens.
- Set `LoginUrl`/`LogoutUrl` so IdentityServer knows where to redirect for authentication.
