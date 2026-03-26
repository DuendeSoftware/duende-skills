# Why the 'department' Claim Doesn't Appear in Access Tokens

## Root Cause

Claims in Duende IdentityServer are **opt-in by scope**. Even if your `IProfileService` emits a `department` claim, it won't appear in the access token unless:

1. The claim type is declared in the `UserClaims` collection of an `ApiScope`, `ApiResource`, or `IdentityResource`
2. The client requests the scope that contains that claim declaration

When `IProfileService.GetProfileDataAsync` is called, the `ProfileDataRequestContext.RequestedClaimTypes` contains only claim types from the resources associated with the scopes the client requested. If you use `context.AddRequestedClaims(claims)` (which is the recommended approach), it filters your claims against `RequestedClaimTypes` — so `department` is silently excluded because it's not in the list.

## Fix: Declare the Claim on the ApiScope

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }  // Declare that this scope includes the department claim
    }
];
```

Now when a client requests the `api1` scope, `department` will be included in `RequestedClaimTypes`, and `AddRequestedClaims` will emit it.

## How AddRequestedClaims Works

```csharp
// In your IProfileService:
public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());

    var claims = new List<Claim>
    {
        new("department", user.Department),
        new("name", user.DisplayName),
    };

    // This ONLY emits claims whose Type is in context.RequestedClaimTypes
    context.AddRequestedClaims(claims);
    
    // If "department" is not in RequestedClaimTypes, it will be silently dropped
}
```

`AddRequestedClaims` is essentially:
```csharp
context.IssuedClaims.AddRange(
    claims.Where(c => context.RequestedClaimTypes.Contains(c.Type)));
```

## Also Ensure the Client Requests the Scope

The client must include `api1` in its `AllowedScopes` and request it at authorization time:

```csharp
new Client
{
    ClientId = "interactive",
    AllowedScopes = { "openid", "profile", "api1" },  // api1 includes department
    // ...
}
```
