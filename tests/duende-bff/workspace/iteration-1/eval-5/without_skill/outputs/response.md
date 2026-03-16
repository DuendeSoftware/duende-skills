# BFF Behind Nginx — Users Logged Out After Auth

## Likely Issues

When running behind a reverse proxy with a sub-path, there are several common issues:

### 1. Forwarded Headers

The BFF doesn't know it's behind a proxy, so it generates incorrect redirect URIs. Add forwarded headers:

```csharp
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});
```

Make sure this is before `UseAuthentication()`.

### 2. Path Base

Since you're mounted at `/app`, configure the path base:

```csharp
app.UsePathBase("/app");
```

### 3. Cookie Configuration

You may need to adjust your cookie settings for the proxy setup. Make sure the cookie domain and path are configured correctly.

These settings should resolve the redirect URI mismatch that's causing the OIDC callback to fail.
