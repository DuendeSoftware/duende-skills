# Missing 'department' Claim in Access Token

## Likely Cause

If your `IProfileService` is emitting the `department` claim but it's not showing up in the access token, the most likely issue is that the claim isn't registered on the scope or resource that the client is requesting.

In IdentityServer, you need to declare which user claims are associated with each scope. If the `department` claim isn't listed, it won't be included.

## Fix

You need to add `department` to the `UserClaims` on your API scope:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }
    }
];
```

Also make sure the client is requesting the `api1` scope in its token request.

## Additional Checks

- Make sure the client has `api1` in its `AllowedScopes`
- Make sure the client actually requests the `api1` scope during authorization
- Check your `IProfileService` implementation to ensure it's actually adding the claim
