# Issuer URI Preservation During Migration

This is one of the most critical aspects of migrating from IdentityServer4 to Duende IdentityServer — if the issuer URI changes, **all existing tokens become invalid and client trust relationships break**.

## The Problem

Your IdentityServer4 instance currently has no explicit `IssuerUri` configured, so it's inferred from the incoming request URL. When you move from IIS on Windows to Kestrel behind nginx on Linux, the request URL seen by the application may change due to:

- Different ports, schemes (HTTP vs HTTPS), or hostnames
- Reverse proxy forwarding headers not being configured correctly
- Path base differences between IIS and nginx

The `iss` claim in every token and the `issuer` field in the `/.well-known/openid-configuration` discovery document must remain exactly the same after migration.

## What to Do

### 1. Find your current issuer value

Before changing anything, check the discovery document of your running IdentityServer4 instance:

```
GET https://your-identity-server/.well-known/openid-configuration
```

Note the `issuer` value in the JSON response — this is the value you must preserve.

### 2. Explicitly set the issuer URI in Duende configuration

In your new Duende IdentityServer `Program.cs`, explicitly set `options.IssuerUri` to match the value from the discovery document:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.example.com";  // match your current issuer exactly
});
```

This ensures the issuer remains the same regardless of how the application is hosted or what URL Kestrel sees behind nginx.

### 3. Configure forwarded headers for nginx

Even with an explicit `IssuerUri`, configure forwarded headers so other URL generation (redirect URIs, etc.) works correctly:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
});

// In the pipeline, before UseIdentityServer:
app.UseForwardedHeaders();
```

## Why This Matters

- **Existing access tokens** have an `iss` claim. APIs validate this claim against the discovery document. If the issuer changes, token validation fails.
- **Existing refresh tokens** are tied to the issuer. A different issuer means refresh token grants fail.
- **Client configurations** in downstream applications have the authority URL configured. If the issuer doesn't match, clients reject the identity provider.
- **Federation trust** with external identity providers will break if they validate the issuer value.

Always set `options.IssuerUri` explicitly when changing hosting infrastructure during a migration.
