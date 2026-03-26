# Missing Department Claim in Access Tokens

## The Issue

If your `IProfileService` is emitting the `department` claim but it's not appearing in the access token, the most likely cause is that the claim isn't being requested through the proper scope configuration.

In IdentityServer, claims need to be associated with a scope or resource. If the claim type isn't declared on any scope the client is requesting, it won't be included.

## Fix

Add the `department` claim to your API scope definition:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }
    }
];
```

Make sure the client also requests this scope:

```csharp
new Client
{
    ClientId = "interactive",
    AllowedScopes = { "openid", "profile", "api1" },
}
```

This tells IdentityServer that when a client requests the `api1` scope, the `department` claim should be included in the token.
