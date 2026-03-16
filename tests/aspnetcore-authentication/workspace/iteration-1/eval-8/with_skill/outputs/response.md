# User.FindFirst("sub") Returns Null — Claim Type Mapping Issue

## The Problem

This is a classic pitfall when working with ASP.NET Core's OIDC and JWT Bearer handlers. By default, the Microsoft OIDC/JWT handlers silently **remap** standard JWT claim types to verbose XML-based .NET claim types. This is why `User.FindFirst("sub")` returns `null` — the `sub` claim has been renamed.

Here's what happens:

| JWT Claim | Gets Mapped To |
|-----------|---------------|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |

So even though the `sub` claim exists in the ID token, by the time it reaches your controller, it's been silently renamed to the long XML URI. `User.FindFirst("sub")` looks for a claim literally named `"sub"`, which no longer exists.

## The Fix

Set `MapInboundClaims = false` on the OIDC or JWT Bearer handler, and configure `TokenValidationParameters` to tell ASP.NET Core which claims to use for `Name` and `Role`:

```csharp
// For OIDC handler (web apps):
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";

    // CRITICAL: Disable claim type mapping
    options.MapInboundClaims = false;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",  // So User.Identity.Name works
        RoleClaimType = "role"   // So User.IsInRole() and [Authorize(Roles=...)] work
    };
});

// For JWT Bearer handler (APIs):
.AddJwtBearer("Bearer", options =>
{
    options.Authority = "https://identity.example.com";

    // CRITICAL: Disable claim type mapping
    options.MapInboundClaims = false;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});
```

After this fix:
- `User.FindFirst("sub")` returns the subject claim correctly
- `User.Identity.Name` returns the `name` claim value
- `User.IsInRole("admin")` checks the `role` claim

## Why This Happens

This is a common pitfall where claims are silently renamed by the handler. Microsoft's OIDC handler was originally designed for WS-Federation and SAML interoperability, where XML-based claim URIs were the standard. When used with modern OIDC/OAuth providers that use short JWT claim names, this mapping causes confusion because claims "disappear" — they're still there, just under different names.

The mapping is on by default (`MapInboundClaims = true`), which means any code using `User.FindFirst("sub")` or similar short claim names will silently fail. Always set `MapInboundClaims = false` when working with IdentityServer or any standard OIDC provider.
