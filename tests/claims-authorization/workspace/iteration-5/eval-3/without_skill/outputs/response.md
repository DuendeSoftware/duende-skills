# `department` claim not showing up in the access token

Emitting a claim from your profile service isn't the whole story in IdentityServer. Claims are associated with **scopes/resources**, and only claims tied to a scope that the client actually requested end up in the token. If `department` isn't wired to a scope, IdentityServer effectively ignores it.

## Declare the claim on a scope or resource

In your `Program.cs` the API scope has no associated user claims:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
];
```

Add `department` to the scope's `UserClaims` so IdentityServer knows this claim belongs to the scope:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }
    }
];
```

You can declare user claims on any of these, depending on where you want the claim to surface:

- `IdentityResource` – for the id_token / userinfo
- `ApiScope` – for access tokens when that scope is requested
- `ApiResource` – for access tokens scoped to a specific API audience

## Make sure the client requests the scope

The claim only flows through when the client requests the scope that carries it. Your client already allows `api1`:

```csharp
AllowedScopes = { "openid", "profile", "email", "api1" }
```

so make sure `api1` is included in the actual token request. If you put `department` on a brand-new scope, add that scope to `AllowedScopes` and request it too.

## Why the profile service alone wasn't enough

Even though your `IProfileService` produces the `department` claim, IdentityServer filters emitted claims against the set of claims that the requested scopes declared. A claim that no requested scope declares gets dropped. Once `department` is listed in a requested scope's `UserClaims`, it will pass through and appear in the token.
