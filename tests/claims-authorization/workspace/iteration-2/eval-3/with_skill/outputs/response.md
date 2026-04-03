# Missing 'department' Claim in Access Tokens

## The Problem

Even though your `IProfileService` emits the `department` claim, it doesn't appear in the access token. This is because **claims in Duende IdentityServer are opt-in by scope**.

## Root Cause: Claims Must Be Declared in UserClaims

When your `IProfileService` uses `context.AddRequestedClaims(claims)`, it filters the claims to only those whose types are in `context.RequestedClaimTypes`. The `RequestedClaimTypes` collection is built from the `UserClaims` declarations on the `IdentityResource`, `ApiScope`, and `ApiResource` objects that the client has requested.

If `department` is not declared in any of these `UserClaims` collections, it will never appear in `RequestedClaimTypes`, and `AddRequestedClaims` will filter it out.

## The Fix

Add `department` to the `UserClaims` collection of the relevant `ApiScope` or `ApiResource`:

```csharp
// Option 1: Declare on an ApiScope
new ApiScope("api1")
{
    UserClaims = { "department" }
}

// Option 2: Declare on an ApiResource (scoped to that specific API)
new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "invoicing.read", "invoicing.write" },
    UserClaims = { "department", "cost_center" }
}

// Option 3: Declare on an IdentityResource (for identity tokens)
new IdentityResource("profile_extended", new[] { "department", "title" })
```

## The Client Must Request the Scope

The client must also have the scope in its `AllowedScopes` and request it at authorization time:

```csharp
new Client
{
    ClientId = "webapp",
    AllowedScopes = { "openid", "profile", "api1" }, // api1 must be here
    // ...
}
```

## How the Pipeline Works

1. Client requests scopes (e.g., `openid profile api1`)
2. IdentityServer builds `RequestedClaimTypes` from the `UserClaims` of all matching resources
3. `IProfileService.GetProfileDataAsync` is called with `context.RequestedClaimTypes` populated
4. `context.AddRequestedClaims(claims)` filters your claims to only those in `RequestedClaimTypes`

If you used `context.IssuedClaims.Add()` directly instead of `AddRequestedClaims`, the claim would bypass this filtering — but this is not recommended for most claims because it ignores scope-based consent.
