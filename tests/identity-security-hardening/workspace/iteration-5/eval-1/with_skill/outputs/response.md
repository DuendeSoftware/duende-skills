# Transport Security Fix — Behind AWS ALB

The `IDX20803` / `http://` issuer problem is the classic symptom of IdentityServer running behind a TLS-terminating proxy **without** `ForwardedHeaders` middleware. The inner request arrives as HTTP, so IdentityServer publishes an `http://` issuer in the discovery document and every downstream API rejects the tokens.

The fix has three parts, and **ordering is critical**: `ForwardedHeaders` must be the *first* middleware so that every later component (including IdentityServer's issuer calculation) sees the correct scheme and client IP.

## Changes to `Program.cs`

Add these service registrations **before** `builder.Build()`:

```csharp
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

// ✅ Required when hosted behind the AWS ALB (TLS terminated at the proxy)
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

    // Restrict to the known ALB IP — never accept forwarded headers from any source.
    // (An attacker who can reach Kestrel directly could otherwise spoof
    //  X-Forwarded-Proto: https from any IP.)
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
    options.ForwardLimit = 1;

    // The middleware seeds KnownNetworks/KnownProxies with loopback defaults;
    // clear them so ONLY the ALB is trusted.
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
});

// ✅ Strong HSTS — preload requires MaxAge >= 1 year
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

// ✅ Force HTTPS redirect to a permanent 308 on port 443
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});
```

Then fix the middleware pipeline ordering after `builder.Build()`:

```csharp
var app = builder.Build();

// 1. ForwardedHeaders MUST be first — everything downstream depends on the
//    corrected scheme/IP, including IdentityServer's issuer URI.
app.UseForwardedHeaders();

// 2. Permanent (308) redirect of any HTTP request to HTTPS
app.UseHttpsRedirection();

// 3. HSTS — tell browsers to always use HTTPS for this host + subdomains
app.UseHsts();

app.UseStaticFiles();
app.UseRouting();

// 4. IdentityServer now sees https:// and publishes the correct issuer
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## Why this resolves the errors

- **`IDX20803` / `http://` issuer** — With `ForwardedHeaders` reading `X-Forwarded-Proto`, IdentityServer sees the original `https` scheme and publishes `https://identity.example.com` as the issuer. Downstream APIs can now fetch the discovery document and validate tokens. (You already have `IssuerUri` set in `appsettings.json`, but the scheme correction is still required for redirect/callback URL generation and cookie security.)
- **HSTS** — `MaxAge = 365 days`, `IncludeSubDomains = true`, `Preload = true` is the minimum production bar and satisfies browser preload-list requirements.
- **HTTPS redirection** — `Status308PermanentRedirect` preserves the HTTP method and is cacheable, unlike the default 307.

## Final middleware order

`ForwardedHeaders → HttpsRedirection → HSTS → StaticFiles → Routing → IdentityServer → Authorization`

> **Security note:** Restricting `KnownProxies` to `10.0.0.1` (and clearing the defaults) is essential. An empty/unrestricted `KnownProxies` list would let anyone who can reach Kestrel forge `X-Forwarded-Proto: https` and bypass your transport controls.
