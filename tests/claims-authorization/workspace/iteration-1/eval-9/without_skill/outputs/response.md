# Claims Filtering in IdentityServer

In IdentityServer, claims are filtered based on the scopes that the client requests.

When you define resources (like `ApiScope` or `IdentityResource`), you can specify which claims should be included when that resource is requested:

```csharp
new ApiScope("api1", "My API")
{
    UserClaims = { "department", "role" }
}
```

When a client requests the `api1` scope, IdentityServer will tell your profile service that `department` and `role` are the requested claim types.

In your `IProfileService`, you can then use these requested claim types to filter which claims to include:

```csharp
public async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await _users.FindBySubjectIdAsync(context.Subject.FindFirst("sub").Value);
    
    // Add claims that match the requested types
    foreach (var requestedType in context.RequestedClaimTypes)
    {
        var claim = GetClaimForUser(user, requestedType);
        if (claim != null)
            context.IssuedClaims.Add(claim);
    }
}
```

This ensures that only claims associated with the requested scopes are included in the token.
