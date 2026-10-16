# Why `department` never reaches the access token

Emitting the claim from your `IProfileService` isn't enough: **claims are opt-in by scope**. Adding the claim to the user/profile service doesn't make IdentityServer include it.

## Cause
`context.AddRequestedClaims(claims)` keeps only claim types in `context.RequestedClaimTypes`, which are built from `UserClaims` on the `IdentityResource`/`ApiScope`/`ApiResource` the client requested. Your `api1` scope declares none:

```csharp
new ApiScope("api1", "My API")   // no UserClaims: department is filtered out
```

## Fix
```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API") { UserClaims = { "department" } }
];
```
Or resource-scoped, emitted only when that API is requested:
```csharp
new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "api1" },
    UserClaims = { "department" }
}
```
Checklist:
1. `department` listed in `UserClaims` of a requested ApiScope/ApiResource (access token) or IdentityResource (id_token/userinfo).
2. Scope in the client's `AllowedScopes` and actually requested (`api1`).
3. Profile service registered: `.AddProfileService<ApplicationProfileService>()`. Note `.AddTestUsers` in your Program.cs uses the test-user profile service otherwise.
4. Emit with `context.AddRequestedClaims(...)`. Adding directly to `context.IssuedClaims` bypasses the filter and consent, so only do that when the claim must always be sent.
5. Enable debug logging for `Duende.IdentityServer`: it shows requested vs. issued claim types and reveals filtering.
6. In the API, set `MapInboundClaims = false` so the claim name isn't remapped.
7. Client credentials tokens have no user, so user claims don't apply there.

```csharp
public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
    context.AddRequestedClaims(new[] { new Claim("department", user!.Department) });
}
```
