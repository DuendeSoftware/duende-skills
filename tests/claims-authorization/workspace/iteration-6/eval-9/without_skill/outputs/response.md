# Claims filtering in Duende IdentityServer

IdentityServer separates *producing* claims from *deciding which to emit*.

1. **IProfileService** knows how to load claims (database etc.).
2. **Resources declare which claim types they need** via `UserClaims`:
   - `IdentityResource.UserClaims` → claims for identity token/userinfo when that scope is requested.
   - `ApiScope.UserClaims` → claims for access tokens when that scope is requested.
   - `ApiResource.UserClaims` → claims for access tokens when any of the resource's scopes is requested (union with the scope's).
3. The union of these becomes `context.RequestedClaimTypes` in `ProfileDataRequestContext`.
4. `context.AddRequestedClaims(claims)` is the filter: it adds only claims whose type is in `RequestedClaimTypes`. Anything else is dropped.

```csharp
new ApiScope("orders", "Orders") { UserClaims = { "department" } };
new ApiResource("orders-api") { Scopes = { "orders" }, UserClaims = { "tenant_id" } };

public Task GetProfileDataAsync(ProfileDataRequestContext ctx)
{
    ctx.AddRequestedClaims(allClaims);      // filtered
    // ctx.IssuedClaims.AddRange(...)       // NOT filtered
    return Task.CompletedTask;
}
```

So claims not declared anywhere won't appear when you use `AddRequestedClaims`. Fix by adding the claim type to `UserClaims` of the relevant scope/resource. If you add straight to `IssuedClaims`, the claim is always emitted, bypassing filtering; use sparingly.

Per-token: `Caller` tells whether it's identity token, access token or userinfo. The `ClaimsFilter`: no `UserClaims` anywhere → only `sub` (plus static ones like `client_id`, `scope`, `auth_time`, `amr`, `idp`).
