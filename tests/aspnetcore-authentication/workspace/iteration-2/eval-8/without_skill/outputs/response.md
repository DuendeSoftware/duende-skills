# User.FindFirst("sub") Returns Null

## The Problem

If `User.FindFirst("sub")` is returning null even though the user is authenticated and the ID token contains the `sub` claim, it's likely a claim mapping issue.

ASP.NET Core's OIDC handler may remap claim types from the JWT format to .NET's XML-based format. The `sub` claim might be mapped to a longer URI like `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.

## How to Check

Try this to see all claims:

```csharp
foreach (var claim in User.Claims)
{
    Console.WriteLine($"{claim.Type}: {claim.Value}");
}
```

You'll likely see the `sub` value under a different claim type name.

## The Fix

You can disable the claim mapping on the OIDC handler:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.MapInboundClaims = false;
    // ... other options
});
```

This preserves the original JWT claim names. After this change, `User.FindFirst("sub")` should work.

You may also want to set the name claim type:

```csharp
options.TokenValidationParameters = new TokenValidationParameters
{
    NameClaimType = "name"
};
```

This ensures `User.Identity.Name` continues to work after disabling the mapping.
