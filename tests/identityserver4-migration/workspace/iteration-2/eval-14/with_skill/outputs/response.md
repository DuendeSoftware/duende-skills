# Issuer URI Migration: Request-Inferred → Explicit Configuration

## The Risk

The issuer URI (`iss` claim in tokens) **must remain identical after migration**. If it changes:
- All existing tokens become invalid
- Client trust relationships break (clients validate tokens against the expected issuer)
- Resource servers reject tokens with the wrong issuer
- Discovery document URLs change, breaking client metadata caching

## Finding Your Current Issuer

Since your IdentityServer4 doesn't have an explicit `IssuerUri` configured, it's inferred from the incoming request URL. Check your current `/.well-known/openid-configuration` discovery document to find the `issuer` value:

```bash
curl https://your-current-identity-server/.well-known/openid-configuration | jq .issuer
```

Note this value exactly — including scheme (https), hostname, port, and path.

## Set It Explicitly in Duende

Configure the issuer URI explicitly in Duende IdentityServer to match the existing value:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Match the exact issuer from your current discovery document
    options.IssuerUri = "https://identity.example.com";
});
```

## Changing Hosting from IIS to Kestrel+nginx

When moving from IIS on Windows to Kestrel behind nginx on Linux, several things change:
- The request URL scheme, host, and port as seen by Kestrel
- Forwarded headers from nginx

Without an explicit `IssuerUri`, the inferred issuer might pick up `http://localhost:5000` from Kestrel instead of the public `https://identity.example.com` from nginx. Setting `options.IssuerUri` explicitly avoids this entirely.

Also configure forwarded headers so that other URL generation (redirect URIs, JWKS URI, etc.) uses the public URL:

```csharp
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});
```
