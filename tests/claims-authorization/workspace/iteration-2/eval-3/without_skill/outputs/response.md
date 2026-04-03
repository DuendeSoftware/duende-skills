# Missing 'department' Claim in Access Tokens

## The Problem

You've added a `department` claim to your users and your `IProfileService` is emitting it, but it's not showing up in access tokens.

## Likely Cause

In IdentityServer, claims in tokens are typically filtered based on what scopes the client has requested. Your profile service may be emitting the claim, but if the token issuance pipeline filters it out, it won't appear.

## Possible Fixes

### 1. Check Your ApiScope or ApiResource Configuration

Make sure the `department` claim is listed in the user claims for the scope:

```csharp
new ApiScope("api1", new[] { "department" })
```

Or if using an `ApiResource`:

```csharp
new ApiResource("my-api")
{
    Scopes = { "api1" },
    UserClaims = { "department" }
}
```

### 2. Check How You're Adding Claims in the Profile Service

Make sure you're adding claims to the issued claims:

```csharp
public Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = GetUser(context.Subject);
    context.IssuedClaims.Add(new Claim("department", user.Department));
    return Task.CompletedTask;
}
```

### 3. Verify the Client Requests the Right Scope

The client configuration must include the scope that contains the `department` claim in its `AllowedScopes`.

### 4. Check If the Token Type Matters

Some claims may only appear in identity tokens or access tokens depending on configuration. If you want claims in the identity token, you might need to set `AlwaysIncludeUserClaimsInIdToken = true` on the client.
