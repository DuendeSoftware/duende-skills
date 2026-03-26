# Issuer URI Preservation During Migration

## Critical Warning: The Issuer URI Must Not Change

The issuer URI (`iss` claim in tokens) is the identity of your IdentityServer. It **must remain identical** after migration. If it changes:

- **All existing access tokens become invalid** — APIs validate the `iss` claim against the expected issuer. A different issuer = rejected tokens.
- **All existing refresh tokens break** — Refresh tokens are tied to the issuer that created them.
- **Client trust relationships break** — Clients are configured with a specific authority URL. If the issuer changes, token validation fails.
- **Discovery document changes** — Clients that cache the discovery document will get mismatched data.

## Your Specific Risk

Your IdentityServer4 has **no explicit `IssuerUri` configured** — the issuer is inferred from the incoming request URL. This means the issuer value depends on:
- The scheme (HTTP vs HTTPS)
- The host name
- The port
- The path

Since you're changing from **IIS on Windows to Kestrel behind nginx on Linux**, any of these could change:
- IIS might have been on `https://identity.example.com:443` while nginx might use a different port or path
- Reverse proxy header forwarding might not be configured correctly, causing Kestrel to see `http://localhost:5000` instead of `https://identity.example.com`

## Steps to Safely Migrate

### Step 1: Record the Current Issuer

Before changing anything, check your current IdentityServer4 discovery document:

```
GET https://your-current-identityserver/.well-known/openid-configuration
```

Note the `"issuer"` value from the JSON response. This is the value you must preserve.

### Step 2: Set the Issuer URI Explicitly in Duende

In your Duende IdentityServer configuration, explicitly set the issuer URI to match:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.example.com";  // Match the value from Step 1
});
```

### Step 3: Configure Forwarded Headers for nginx

Since you're behind nginx, configure forwarded headers so IdentityServer sees the correct scheme, host, and port:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
});

// In the pipeline, before UseIdentityServer:
app.UseForwardedHeaders();
```

And in your nginx configuration:
```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Host $host;
```

### Step 4: Verify After Deployment

After deploying, check the discovery document again:

```
GET https://your-new-deployment/.well-known/openid-configuration
```

Confirm the `"issuer"` value matches exactly what it was before.

## Key Takeaway

Setting `options.IssuerUri` explicitly is the safest approach — it eliminates dependence on request URL inference, which is fragile across hosting changes.
