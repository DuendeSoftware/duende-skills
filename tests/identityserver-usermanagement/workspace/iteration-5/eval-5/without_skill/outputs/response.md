# Getting User Claims into IdentityServer Tokens

In IdentityServer, the claims that end up in ID tokens are produced by the **profile service** (`IProfileService`) and gated by the **identity resources / scopes** a client requests. Here's how to make a user's email and custom profile attributes appear in the ID token.

## 1. How Claims Flow

- A client requests identity scopes (e.g. `openid profile email`).
- Each identity scope (an `IdentityResource`) declares which **user claim types** it maps.
- IdentityServer calls your **`IProfileService`** to fetch the actual claim values for that user.
- Matching claims are emitted into the ID token (and/or userinfo endpoint).

Your existing config already registers `OpenId`, `Profile`, and `Email` identity resources, and the `web` client already allows `openid profile email`.

## 2. Provide a Profile Service

IdentityServer needs to know how to load a user's claims. Implement `IProfileService`:

```csharp
public class ProfileService : IProfileService
{
    private readonly IUserStore _users;   // your user source

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var user = await _users.FindByIdAsync(context.Subject.GetSubjectId());

        var claims = new List<Claim>
        {
            new("email", user.Email),
            new("email_verified", user.EmailConfirmed ? "true" : "false", ClaimValueTypes.Boolean),
            new("name", user.DisplayName),
            // custom profile attributes:
            new("department", user.Department),
            new("employee_id", user.EmployeeId)
        };

        // Only emit claims the requested scopes actually asked for
        context.AddRequestedClaims(claims);
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

Register it:

```csharp
builder.Services.AddIdentityServer(/* ... */)
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddProfileService<ProfileService>();
```

> If you use ASP.NET Core Identity, `AddAspNetIdentity<TUser>()` registers a profile service for you and maps standard claims automatically.

## 3. Expose Custom Attributes via a Custom Identity Resource

Standard scopes only carry standard claims. For your custom attributes, define a **custom identity resource** that declares those claim types, and allow it on the client:

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email(),
    new IdentityResource("company_profile", new[] { "department", "employee_id" })
];
```

```csharp
// client
AllowedScopes = { "openid", "profile", "email", "company_profile", "api1" }
```

## 4. Put Claims in the ID Token

By default some claims come only from the userinfo endpoint. To force them into the ID token itself:

```csharp
new Client
{
    // ...
    AlwaysIncludeUserClaimsInIdToken = true
}
```

## Summary

- Claims are produced by **`IProfileService`** and gated by requested **identity scopes**.
- `email`/`email_verified` come from the `email` scope; `sub` from `openid`; profile claims from `profile`.
- Expose **custom attributes** through a **custom identity resource** and allow its scope on the client.
- Use `AddRequestedClaims(...)` so you only emit what was requested, and `AlwaysIncludeUserClaimsInIdToken` if you need them in the ID token directly.
