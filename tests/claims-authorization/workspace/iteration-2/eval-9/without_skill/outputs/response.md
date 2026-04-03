# Claims Filtering in IdentityServer

## How It Works

IdentityServer uses a scope-based claims filtering system. When a token is issued, not all claims are included — only those that match the requested scopes.

## The Process

1. A client requests an access token with specific scopes (e.g., `openid profile api1`)
2. IdentityServer looks up the resource definitions for those scopes
3. Each resource (ApiScope, ApiResource, IdentityResource) has a `UserClaims` property listing which claim types it requires
4. These claim types are passed to the `IProfileService` as "requested claims"
5. The profile service should only return claims that match

## Declaring Claims on Resources

```csharp
new ApiScope("api1")
{
    UserClaims = { "department", "role" }
}
```

This tells IdentityServer that when a client requests the `api1` scope, the `department` and `role` claims should be included in the token.

## In Your Profile Service

The `ProfileDataRequestContext` contains `RequestedClaimTypes` which lists all the claim types from the requested scopes:

```csharp
public Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    // context.RequestedClaimTypes contains the list of claims the scopes require
    foreach (var claimType in context.RequestedClaimTypes)
    {
        var claim = GetClaimForUser(context.Subject, claimType);
        if (claim != null)
        {
            context.IssuedClaims.Add(claim);
        }
    }
    return Task.CompletedTask;
}
```

## Why Claims Might Not Appear

- The claim type isn't listed in `UserClaims` on any requested scope/resource
- The client doesn't request the scope that contains the claim
- The profile service doesn't emit the claim
- For identity tokens, API scope claims are not included by default
