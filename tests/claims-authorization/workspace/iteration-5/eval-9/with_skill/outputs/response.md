# How claims filtering works in Duende IdentityServer

The core rule: **claims are opt-in by scope.** Emitting a claim from `IProfileService` is necessary but not sufficient — IdentityServer only *asks for* and *lets through* claim types that a requested resource has declared. Here's the full chain.

## 1. Resources declare which claim types belong to them

Each `IdentityResource`, `ApiScope`, and `ApiResource` has a `UserClaims` collection listing the claim types associated with it.

```csharp
// On an ApiScope — emitted when this scope is requested
new ApiScope("api.read")
{
    UserClaims = { "department", "cost_center" }
};

// On an ApiResource — emitted only when this API (audience) is requested
new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "invoicing.read" },
    UserClaims = { "approval_limit" }
};
```

## 2. Requested scopes → `RequestedClaimTypes`

When a client requests a token, IdentityServer resolves the requested scopes to their resources and gathers the union of their `UserClaims`. That set is handed to your profile service on the `ProfileDataRequestContext`:

- `IProfileService.GetProfileDataAsync(ProfileDataRequestContext context)` is called at token issuance.
- `context.RequestedClaimTypes` contains exactly those claim types (derived from the `UserClaims` of the resolved resources). If a claim type isn't declared on any requested resource, it won't be in this list.

## 3. `AddRequestedClaims` filters against `RequestedClaimTypes`

Inside the profile service:

```csharp
public override Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var claims = new List<Claim>
    {
        new("department", "engineering"),
        new("cost_center", "CC-100"),
        new("secret_internal", "xyz"),
    };

    // Only emits claims whose Type is present in context.RequestedClaimTypes.
    // "secret_internal" is dropped unless a requested resource declared it.
    context.AddRequestedClaims(claims);

    return Task.CompletedTask;
}
```

`AddRequestedClaims` is the helper that enforces the filter: it iterates your claims and keeps only those whose type appears in `context.RequestedClaimTypes`. This is precisely why a claim "doesn't appear unless I declare it somewhere" — if it's not in a requested resource's `UserClaims`, it's not in `RequestedClaimTypes`, so `AddRequestedClaims` filters it out.

## Putting it together

To surface a new claim you need **all** of:

1. **Declare** the claim type in a resource's `UserClaims` (`IdentityResource`, `ApiScope`, or `ApiResource`).
2. **Allow + request** the scope: add it to the client's `AllowedScopes` and include it in the request.
3. **Emit** it from the profile service (typically via `AddRequestedClaims`).

## Escape hatches

- To emit a claim **regardless** of requested scopes, add it directly to `context.IssuedClaims` (bypasses the filter — use for mandatory claims).
- `AlwaysIncludeUserClaimsInIdToken = true` on the client forces user claims into the id_token, bypassing the "identity tokens are minimal" default (at the cost of token size).

## Diagnosing

Enable `Duende.IdentityServer` debug logging — the default profile service logs the requested vs. issued claim types, which immediately reveals whether your claim was filtered out by `RequestedClaimTypes` (a declaration/scope problem) rather than never emitted (a profile-service problem).
