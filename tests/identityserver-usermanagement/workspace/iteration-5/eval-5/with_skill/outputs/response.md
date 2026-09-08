# Getting User Claims into Tokens with Duende User Management

When you call `AddUserManagement()` on your IdentityServer builder, the claims pipeline is wired up for you — you don't have to write a custom `IProfileService`. User profile attributes flow into ID/access tokens based on the scopes the client requests.

## AddUserManagement() Registers IProfileService Automatically

`AddUserManagement()` **automatically registers an `IProfileService`** implementation. This is the component IdentityServer calls to emit claims into tokens. Because it's registered for you, User Management users' profile data is delivered into tokens with no extra code.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;

    // Point IdentityServer at the User Management account pages
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        options.AddSqliteStore("Data Source=users.db");
        // ...OTP dispatcher, etc.
    });
```

## Claims Are Mapped from Scopes

The provided profile service maps user profile attributes to claims **based on the identity scopes the client requests**:

| Requested scope | Claims emitted |
|-----------------|----------------|
| `openid` | `sub` (the user's stable identifier) |
| `profile` | `name`, `given_name`, `family_name`, etc. |
| `email` | `email`, `email_verified` |

Your existing `Config.IdentityResources` already includes `OpenId`, `Profile`, and `Email`, and your `web` client already allows `openid profile email` — so requesting those scopes will place `sub`, `name`, `email`, and `email_verified` into the ID token.

## Exposing Custom Profile Attributes

User Management stores custom user attributes as key-value pairs. To get **custom attributes into ID tokens**, expose them through a **custom identity resource** that declares the claim types, then allow that scope on the client:

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email(),

    // Custom identity resource surfacing extra profile attributes
    new IdentityResource(
        name: "company_profile",
        userClaims: new[] { "employee_id", "department" })
];
```

```csharp
// On the client:
AllowedScopes = { "openid", "profile", "email", "company_profile", "api1" }
```

When the client requests `company_profile`, the matching user attributes (`employee_id`, `department`) are mapped to claims and included in the token.

> Tip: If you want these claims in the **ID token** specifically (rather than only from the userinfo endpoint), set `AlwaysIncludeUserClaimsInIdToken = true` on the client.

## Set LoginUrl / LogoutUrl

So IdentityServer redirects to the User Management account pages during interactive flows, set them in the IdentityServer options (shown above):

```csharp
options.UserInteraction.LoginUrl = "/Account/Login";
options.UserInteraction.LogoutUrl = "/Account/Logout";
```

## Summary

- `AddUserManagement()` **auto-registers `IProfileService`** — no custom profile service needed.
- Standard claims are mapped by **requested scope** (`openid` → `sub`, `profile` → name claims, `email` → `email`/`email_verified`).
- Surface **custom attributes** via a **custom identity resource** (and allow its scope on the client).
- Set **`LoginUrl`/`LogoutUrl`** so interactive flows hit your account pages.
