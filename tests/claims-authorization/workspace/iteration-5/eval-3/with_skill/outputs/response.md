# Why your `department` claim never reaches the access token

Your profile service is doing its job, but in Duende IdentityServer **claims are opt-in by scope**. Emitting a claim from `IProfileService` is necessary but not sufficient — IdentityServer only *asks for* and *lets through* claim types that a requested resource has declared. If `department` isn't declared on a resource the client requested, it gets filtered out before it ever hits the token.

## The two things that must be true

1. **The claim type must be declared in a `UserClaims` collection** of an `IdentityResource`, `ApiScope`, or `ApiResource`.
2. **The client must actually request the scope** that carries that claim (it must be in `AllowedScopes` and included in the request).

## How the filtering works (`RequestedClaimTypes` ↔ `AddRequestedClaims`)

When a token is issued, IdentityServer builds `ProfileDataRequestContext.RequestedClaimTypes` from the `UserClaims` of all the resources resolved for the request (i.e. the requested scopes). Inside your profile service:

```csharp
context.AddRequestedClaims(claims);
```

`AddRequestedClaims` **filters** the list you hand it, emitting only the claims whose type appears in `RequestedClaimTypes`. So if `department` isn't in any requested resource's `UserClaims`, `RequestedClaimTypes` won't contain `"department"`, and `AddRequestedClaims` will silently drop your `department` claim. That's exactly your symptom.

## The fix — declare `department` on the scope

Your current config (`Program.cs`) has a bare API scope:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")   // ❌ no UserClaims → "department" never requested
];
```

Add `department` to the scope's `UserClaims`:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }   // ✅ now part of RequestedClaimTypes when api1 is requested
    }
];
```

If instead you want it in the **id_token** (for the interactive client), declare it on an `IdentityResource` and add that scope to the client:

```csharp
new IdentityResource("department_info", "Your department", new[] { "department" })
```

Or, to scope it to a single API only, put it on an `ApiResource`:

```csharp
new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "api1" },
    UserClaims = { "department" }
}
```

## Make sure the client requests the scope

The client already allows `api1`:

```csharp
AllowedScopes = { "openid", "profile", "email", "api1" }
```

so it just needs to include `api1` in the token request (which the M2M client already does). If you declared `department` on a *new* scope/identity resource, add that scope to `AllowedScopes` and request it.

## Summary

- Emitting from `IProfileService` isn't enough — claims are opt-in by scope.
- Declare `department` in the `UserClaims` of an `ApiScope` (or `ApiResource`/`IdentityResource`).
- Ensure the client requests that scope.
- `AddRequestedClaims` only lets through claim types present in `RequestedClaimTypes`, which is built from those declared `UserClaims` — that's why an undeclared claim disappears.
