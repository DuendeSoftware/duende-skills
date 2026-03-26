# How Claims Filtering Works in Duende IdentityServer

## The Claims Pipeline

When a client requests a token, IdentityServer determines which claims to include through a scope-driven filtering process:

1. **Client requests scopes** (e.g., `openid profile api1`)
2. **IdentityServer resolves resources** — each scope maps to an `IdentityResource`, `ApiScope`, or `ApiResource`, each of which has a `UserClaims` collection
3. **`RequestedClaimTypes` is assembled** — the union of all `UserClaims` from all matched resources
4. **`IProfileService.GetProfileDataAsync` is called** — with `ProfileDataRequestContext` containing `RequestedClaimTypes`
5. **`AddRequestedClaims` filters claims** — only claims whose `Type` is in `RequestedClaimTypes` are emitted

## ProfileDataRequestContext.RequestedClaimTypes

The `RequestedClaimTypes` property on `ProfileDataRequestContext` contains the claim types that the client is entitled to receive, based on the scopes it requested. This is populated automatically by IdentityServer before calling your profile service.

```csharp
public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    // RequestedClaimTypes = ["name", "email", "department", ...]
    // Derived from UserClaims on matched IdentityResources/ApiScopes/ApiResources

    var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());

    var claims = new List<Claim>
    {
        new("name", user.DisplayName),
        new("email", user.Email),
        new("department", user.Department),
        new("internal_id", user.InternalId),  // Not in any scope's UserClaims
    };

    // Only emits claims whose Type is in RequestedClaimTypes
    // "internal_id" will be silently dropped if not declared on any resource
    context.AddRequestedClaims(claims);
}
```

## Declaring UserClaims on Resources

```csharp
// IdentityResource — claims go into identity tokens (or userinfo)
new IdentityResource("profile", new[] { "name", "email", "picture" })

// ApiScope — claims go into access tokens when this scope is requested
new ApiScope("api1", "My API")
{
    UserClaims = { "department", "role" }
}

// ApiResource — claims scoped to a specific API (resource indicator)
new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "invoicing.read" },
    UserClaims = { "cost_center", "approval_limit" }
}
```

## How AddRequestedClaims Works

`AddRequestedClaims` is essentially:

```csharp
// Pseudo-implementation
public void AddRequestedClaims(IEnumerable<Claim> claims)
{
    var matched = claims.Where(c => RequestedClaimTypes.Contains(c.Type));
    IssuedClaims.AddRange(matched);
}
```

If a claim type is not in `RequestedClaimTypes`, it's silently dropped. This is by design — it enforces consent and scope-based filtering.

## Bypassing the Filter

For claims that must always be present (e.g., `tenant_id` for multi-tenancy), add them directly:

```csharp
context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));
```

## AlwaysIncludeUserClaimsInIdToken

Setting `AlwaysIncludeUserClaimsInIdToken = true` on a client forces all profile claims into the identity token, bypassing the userinfo endpoint. Use sparingly — prefer `GetClaimsFromUserInfoEndpoint = true` in the client OIDC handler.
