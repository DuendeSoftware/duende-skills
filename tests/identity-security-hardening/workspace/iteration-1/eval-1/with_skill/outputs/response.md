# Transport Security Fix — Reverse Proxy + HSTS + HTTPS Redirection

## Problem

Behind an AWS ALB that terminates TLS, IdentityServer sees HTTP requests and publishes an `http://` issuer URI in the discovery document. Downstream APIs reject all tokens because the issuer doesn't match. Additionally, there's no HSTS or HTTPS enforcement.

## Solution

### 1. Configure ForwardedHeaders (restricted to known proxy)

```csharp
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

    // Restrict to known proxy IP — never accept from any source
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
    options.ForwardLimit = 1;
});
```

### 2. Configure HSTS with strong settings

```csharp
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});
```

### 3. Configure HTTPS Redirection with 308 Permanent Redirect

```csharp
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});
```

### 4. Middleware Pipeline Ordering

The ordering is critical. `UseForwardedHeaders()` must be the very first middleware so all subsequent middleware (including IdentityServer) sees the correct scheme:

```csharp
var app = builder.Build();

// 1. ForwardedHeaders FIRST — restores original scheme/IP from proxy headers
app.UseForwardedHeaders();

// 2. HTTPS redirection — redirects any HTTP request with 308
app.UseHttpsRedirection();

// 3. HSTS — tells browsers to always use HTTPS
app.UseHsts();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```

## Why This Fixes the Discovery Document Issue

Without `ForwardedHeaders`, IdentityServer sees the request scheme as `http://` (because ALB terminated TLS). The discovery document at `/.well-known/openid-configuration` publishes the issuer as `http://identity.example.com`. When APIs validate tokens, the `iss` claim doesn't match the expected `https://` issuer, causing `IDX20803` errors.

By configuring `ForwardedHeaders` with `XForwardedProto`, ASP.NET Core restores the original HTTPS scheme from the `X-Forwarded-Proto` header set by the ALB. IdentityServer then correctly publishes `https://identity.example.com` as the issuer.

Restricting `KnownProxies` to `10.0.0.1` prevents an attacker from spoofing the `X-Forwarded-Proto` header from an arbitrary IP.
