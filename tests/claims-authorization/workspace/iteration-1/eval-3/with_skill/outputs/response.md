# Why 'department' Doesn't Appear in the Access Token

## Root Cause: Claims Are Opt-In by Scope

In Duende IdentityServer, **claims are opt-in by scope**. Even if your `IProfileService` emits a `department` claim, it won't appear in the access token unless:

1. The claim type is declared in the `UserClaims` collection of an `IdentityResource`, `ApiScope`, or `ApiResource`
2. The client requests the scope that contains that claim declaration

Your `IProfileService` uses `context.AddRequestedClaims(claims)`, which filters claims down to only those whose types appear in `context.RequestedClaimTypes`. The `RequestedClaimTypes` collection is built from the `UserClaims` of the scopes the client requested.

If `department` isn't listed in any scope's `UserClaims`, it won't be in `RequestedClaimTypes`, and `AddRequestedClaims` will filter it out — even though your profile service emitted it.

## The Fix

Add `department` to the `UserClaims` collection on your `ApiScope` (or `ApiResource`):

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }
    }
];
```

Or on an `ApiResource` if the claim is specific to that API:

```csharp
new ApiResource("my_api", "My API")
{
    Scopes = { "api1" },
    UserClaims = { "department" }
}
```

Or on an `IdentityResource` if it's part of the user's identity profile:

```csharp
new IdentityResource("department_info", "Department Information", new[] { "department" })
```

## Also: Ensure the Client Requests the Scope

The client must include the scope in its `AllowedScopes` and request it during authorization:

```csharp
new Client
{
    ClientId = "interactive",
    AllowedScopes = { "openid", "profile", "api1" }, // api1 must be here
    // ...
}
```

## How AddRequestedClaims and RequestedClaimTypes Work

When you call `context.AddRequestedClaims(claims)`, it:

1. Looks at `context.RequestedClaimTypes` — which is populated from the `UserClaims` of all the scopes/resources the client requested
2. Filters your claims collection to only include claim types present in `RequestedClaimTypes`
3. Adds the filtered claims to `context.IssuedClaims`

So `AddRequestedClaims` is a convenience method that enforces scope-based claim filtering. If `department` isn't in any requested scope's `UserClaims`, `RequestedClaimTypes` won't contain `"department"`, and the claim is silently dropped.

If you need a claim to always appear regardless of scopes (bypassing this filtering), use `context.IssuedClaims.Add(...)` directly instead.
