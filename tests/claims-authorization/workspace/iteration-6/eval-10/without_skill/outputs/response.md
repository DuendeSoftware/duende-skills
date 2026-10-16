# `department` in userinfo but not in id_token

Before rewriting `IProfileService`: your service is almost certainly working, because userinfo proves it returns the claim. The difference is in how IdentityServer treats ID tokens.

## Likely cause
By default, for flows that also return an access token (code flow), IdentityServer keeps ID tokens small. Client setting `AlwaysIncludeUserClaimsInIdToken` defaults to `false`, so user claims are **not** put in the id_token; the client is expected to fetch them from userinfo. Userinfo is filtered by the identity scopes requested.

## Diagnose
1. Decode the id_token and confirm `department` is missing.
2. Check the client: `AlwaysIncludeUserClaimsInIdToken`?
3. Check an `IdentityResource` that includes `department` in `UserClaims` and that the client requests that scope and has it in `AllowedScopes`.
4. Turn on Debug logging for `Duende.IdentityServer` and inspect `context.RequestedClaimTypes` and `context.Caller` in the profile service (`ClaimsProviderIdentityToken` vs `UserInfoEndpoint`).
5. On the web app side, the OIDC handler's `ClaimActions` / `GetClaimsFromUserInfoEndpoint` may also drop unmapped claims (`MapUniqueJsonKey("department","department")`).

## Fix
Option A (preferred, small tokens): leave the id_token alone and set `options.GetClaimsFromUserInfoEndpoint = true` plus `ClaimActions.MapUniqueJsonKey("department", "department")` in the web app.

Option B: put claims in the id_token:
```csharp
new Client { ClientId = "web", AlwaysIncludeUserClaimsInIdToken = true, ... }
```
and make sure an identity resource declares it:
```csharp
new IdentityResource("dept", new[] { "department" })
```
requested as scope `dept`.
