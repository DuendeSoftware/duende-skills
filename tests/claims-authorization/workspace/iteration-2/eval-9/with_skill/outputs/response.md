# How Claims Filtering Works in Duende IdentityServer

## The Claims Pipeline

When a token is issued, Duende IdentityServer calls `IProfileService.GetProfileDataAsync`. The `ProfileDataRequestContext` contains a `RequestedClaimTypes` collection that determines which claims will be included in the token.

## How RequestedClaimTypes Is Built

1. The client requests specific scopes (e.g., `openid profile api1`)
2. IdentityServer resolves these scopes to their corresponding `IdentityResource`, `ApiScope`, and `ApiResource` definitions
3. Each of these resources has a `UserClaims` collection listing the claim types they require
4. The union of all `UserClaims` from all matched resources becomes `RequestedClaimTypes`

## AddRequestedClaims vs. IssuedClaims.Add

In your `IProfileService.GetProfileDataAsync`:

```csharp
public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());

    var allClaims = new List<Claim>
    {
        new(JwtClaimTypes.Name, user.DisplayName),
        new(JwtClaimTypes.Email, user.Email),
        new("department", user.Department),
        new("cost_center", user.CostCenter),
    };

    // AddRequestedClaims filters: only claims whose Type is in
    // context.RequestedClaimTypes will be added to IssuedClaims
    context.AddRequestedClaims(allClaims);

    // IssuedClaims.Add bypasses filtering — always emitted
    context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));
}
```

- **`context.AddRequestedClaims(claims)`** — Filters your claims list to only those whose `Type` is in `context.RequestedClaimTypes`. This respects scope-based consent.
- **`context.IssuedClaims.Add(claim)`** — Adds the claim directly with no filtering. Use for mandatory claims.

## Declaring UserClaims on Resources

For a claim to appear in `RequestedClaimTypes`, it must be declared on a resource:

```csharp
// ApiScope — claims emitted when this scope is requested
new ApiScope("api1")
{
    UserClaims = { "department", "cost_center" }
}

// ApiResource — claims scoped to this specific API
new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "invoicing.read" },
    UserClaims = { "approval_limit" }
}

// IdentityResource — claims emitted for identity token / userinfo
new IdentityResource("profile_extended", new[] { "department", "title" })
```

## Common Mistake

If your `IProfileService` emits a claim but it doesn't appear in the token:

1. Check that the claim type is declared in `UserClaims` on the relevant `ApiScope`, `ApiResource`, or `IdentityResource`
2. Check that the client is requesting the scope that contains that claim
3. If you used `AddRequestedClaims`, verify the claim type is in `RequestedClaimTypes` — if not, it was filtered out

## AlwaysIncludeUserClaimsInIdToken

For identity tokens specifically, claims from `ApiScope`/`ApiResource` are NOT included by default (only claims from `IdentityResource` are). Setting `AlwaysIncludeUserClaimsInIdToken = true` on the client bypasses this and embeds all profile claims — but this increases token size and should be used sparingly.
