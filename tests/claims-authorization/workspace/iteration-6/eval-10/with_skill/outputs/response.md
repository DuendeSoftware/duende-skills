# `department` in userinfo but not in the id_token

Check this before touching `IProfileService`: the fact that `/connect/userinfo` returns `department` shows the profile service and resource declarations already work. The id_token is minimal **by default**.

## Why
For code flow, `GetProfileDataAsync` can be called up to three times per login, distinguished by `context.Caller`:

| Caller | Token |
|---|---|
| `ClaimsProviderIdentityToken` | id_token, built with `includeAllIdentityClaims = false`, so minimal |
| `ClaimsProviderAccessToken` | access token |
| `UserInfoEndpoint` | `/connect/userinfo` |

Identity claims only go into the id_token when `Client.AlwaysIncludeUserClaimsInIdToken = true` (or no access token is issued). Otherwise the client is expected to call userinfo.

## Diagnose (in order)
1. Confirm the claim is in userinfo (it is). Then the profile service is fine.
2. Check your web app OIDC options: is `GetClaimsFromUserInfoEndpoint = true`? Probably not.
3. Enable `Duende.IdentityServer` debug logging; the profile service logs requested vs. issued claim types per caller.
4. Verify `department` is in `UserClaims` of an `IdentityResource` the client requests (e.g. `new IdentityResource("department_info", ["department"])`, in `AllowedScopes`, requested in scope).
5. If the client uses `MapInboundClaims`/`ClaimActions` with `Clear()`, make sure the claim isn't whitelisted out: `options.ClaimActions.MapJsonKey("department", "department")`.

## Likely fix (preferred)
```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.MapInboundClaims = false;
    options.GetClaimsFromUserInfoEndpoint = true;   // pull department from userinfo
    options.Scope.Add("department_info");
    options.ClaimActions.MapJsonKey("department", "department");
    options.SaveTokens = true;
});
```

## Alternative
Put claims in the id_token only if the client can't call userinfo (e.g. native app):
```csharp
new Client { ClientId = "native", AlwaysIncludeUserClaimsInIdToken = true, ... }
```
Trade-offs: bigger tokens, stale data until the id_token expires, no userinfo freshness. So use sparingly.

No rewrite of the `IProfileService` is needed.
