# Why User.FindFirst("sub") Returns Null

## The Problem

This is a classic claim type mapping issue. By default, the Microsoft OIDC and JWT Bearer handlers **remap** JWT claim names to long XML-based .NET claim type URIs. The `sub` claim from your ID token is renamed to:

```
http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier
```

So when you call `User.FindFirst("sub")`, it returns `null` — not because the claim is missing, but because it was **silently renamed** by the handler. The claim exists, just under a different name.

### The Full Mapping Table

| JWT Claim | Default .NET Mapping |
|-----------|---------------------|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |

This is a common pitfall where claims are silently renamed by the handler, and it trips up many developers.

## The Fix

### Step 1: Disable Claim Type Mapping

Set `MapInboundClaims = false` on the OIDC handler (or JWT Bearer handler):

```csharp
// For OIDC handler
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";

    // ✅ Disable claim type remapping
    options.MapInboundClaims = false;

    // ... other options
});

// For JWT Bearer handler
.AddJwtBearer("Bearer", options =>
{
    options.Authority = "https://identity.example.com";

    // ✅ Disable claim type remapping
    options.MapInboundClaims = false;

    // ... other options
});
```

### Step 2: Set NameClaimType and RoleClaimType

After disabling mapping, ASP.NET Core's `User.Identity.Name` and `User.IsInRole()` won't work because they still expect the XML URI claim types. Fix this by telling ASP.NET Core which claim types to use:

```csharp
options.TokenValidationParameters = new TokenValidationParameters
{
    NameClaimType = "name",   // User.Identity.Name reads the "name" claim
    RoleClaimType = "role"    // User.IsInRole() checks the "role" claim
};
```

### After the Fix

With `MapInboundClaims = false`:
- `User.FindFirst("sub")` → returns the subject claim ✅
- `User.FindFirst("name")` → returns the name claim ✅
- `User.FindFirst("email")` → returns the email claim ✅
- `User.Identity.Name` → works (reads the "name" claim) ✅
- `User.IsInRole("admin")` → works (checks the "role" claim) ✅
