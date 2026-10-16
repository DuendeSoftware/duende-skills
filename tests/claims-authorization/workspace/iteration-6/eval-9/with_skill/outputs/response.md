# Claims filtering in Duende IdentityServer

**Claims are opt-in by scope.** `IProfileService` knows how to *load* claims; resources declare which claim types they *need*. Only the intersection is emitted when you use `AddRequestedClaims`.

## The pieces
| Piece | `UserClaims` affect |
|---|---|
| `IdentityResource` | id_token and userinfo when that identity scope is requested |
| `ApiScope` | access token when that scope is requested |
| `ApiResource` | access token whenever any of its `Scopes` is requested (resource-based filtering, union with the scope's claims) |

```csharp
new IdentityResource("department_info", ["department"], "Your department");

new ApiScope("invoicing.read") { UserClaims = { "department" } }

new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "invoicing.read", "invoicing.write" },
    UserClaims = { "cost_center", "approval_limit" }   // only in tokens for this API
}
```

## What happens at issuance
1. The client requests scopes (`AllowedScopes` must contain them).
2. IdentityServer resolves resources and unions their `UserClaims` into `ProfileDataRequestContext.RequestedClaimTypes`.
3. It calls `GetProfileDataAsync`; `context.Caller` says whether it's `ClaimsProviderIdentityToken`, `ClaimsProviderAccessToken` or `UserInfoEndpoint`.
4. `context.AddRequestedClaims(claims)` keeps only claims whose type is in `RequestedClaimTypes` (this respects consent).

```csharp
public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());

    // Always emitted; bypasses filtering and consent
    context.IssuedClaims.Add(new Claim("tenant_id", user!.TenantId));

    // Filtered by RequestedClaimTypes
    context.AddRequestedClaims(new[] { new Claim("department", user.Department) });
}
```

## Why your claim is missing
`department` isn't in any `UserClaims` of the requested scope/resource, so `AddRequestedClaims` removes it. Fix: add it to the `ApiScope` or `ApiResource` the client requests.

```csharp
new ApiScope("api.read") { UserClaims = { "department" } }
```

## Also check
- The client has the scope in `AllowedScopes` and requests it.
- Adding to `IssuedClaims` directly bypasses the filter, so reserve it for must-have claims.
- Debug logging of `Duende.IdentityServer` shows requested vs. issued claim types.
- Identity token is minimal by default (`AlwaysIncludeUserClaimsInIdToken = false`); identity claims show up at userinfo.
- On the API side set `MapInboundClaims = false` so names aren't remapped.
