# Understanding claims filtering in IdentityServer

The key idea is that in IdentityServer claims are **scope-driven**: just producing a claim in your `IProfileService` doesn't guarantee it lands in a token. The token only carries claim types that some requested scope/resource has "asked for." Here's how the pieces relate.

## UserClaims on scopes and resources

`IdentityResource`, `ApiScope`, and `ApiResource` each expose a `UserClaims` collection. Listing a claim type there declares "when this scope/resource is requested, these user claims are relevant."

```csharp
new ApiScope("api.read")
{
    UserClaims = { "department" }   // department is relevant when api.read is requested
};

new ApiResource("invoicing", "Invoicing API")
{
    Scopes = { "invoicing.read" },
    UserClaims = { "cost_center" }  // only when the invoicing API is requested
};
```

- `IdentityResource.UserClaims` → surface in the id_token / userinfo.
- `ApiScope.UserClaims` → surface in the access token when that scope is requested.
- `ApiResource.UserClaims` → surface in the access token scoped to that API audience.

## How this reaches the profile service

When a token is issued, IdentityServer looks at the scopes the client requested, resolves them to their resources, and collects all the declared `UserClaims`. That collected set of requested claim types is what your `GetProfileDataAsync` is expected to honor — it's given to you on the request context as the list of claim types that were actually requested.

## AddRequestedClaims

`context.AddRequestedClaims(claims)` is the helper that ties it together: it takes the candidate claims you built and only keeps the ones whose type was in that requested set, adding those to the issued claims. So:

```csharp
public async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var claims = new List<Claim>
    {
        new Claim("department", "engineering"),
        new Claim("internal_note", "..."),   // not declared anywhere
    };

    // Only "department" survives — and only if a requested scope declared it.
    context.AddRequestedClaims(claims);
}
```

If you had instead added everything straight to `context.IssuedClaims`, it would bypass this filtering (which is how you'd force a claim to always appear).

## Why your claim didn't show up

It wasn't declared on any resource the client requested, so it wasn't part of the requested claim types, so `AddRequestedClaims` filtered it out. To fix it:

1. Add the claim type to the `UserClaims` of the relevant `ApiScope` / `ApiResource` (or `IdentityResource` for id_token/userinfo).
2. Make sure the client is allowed to request, and does request, that scope.
3. Keep emitting it via `AddRequestedClaims`.
