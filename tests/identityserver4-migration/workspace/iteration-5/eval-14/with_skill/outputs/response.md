# Preserving the issuer when migrating hosting (IIS/Windows → Kestrel/nginx/Linux)

Your IS4 instance doesn't set `IssuerUri` explicitly — it **infers the issuer from the incoming request URL**. That makes the issuer sensitive to hosting changes, which is exactly what you're doing (IIS on Windows → Kestrel behind nginx on Linux). This is the main thing to watch.

## Why the issuer matters

The **issuer URI is the `iss` claim** in every token and the `issuer` value in your discovery document. Clients and APIs validate incoming tokens against the issuer they expect. If the issuer **changes**, then:

- **Existing/issued tokens become invalid** — relying parties reject them because `iss` no longer matches.
- **Client trust relationships break** — OIDC clients pin the issuer (and validate it as part of the discovery/metadata contract); a mismatch fails validation.

Because you infer the issuer from the request, a change in scheme, host, port, or path — very easy to introduce when moving to Kestrel behind nginx — will silently change the issuer.

## What to do

**1. Find your current issuer.** On the existing IIS-hosted instance, request:

```
https://your-current-host/.well-known/openid-configuration
```

and note the exact **`issuer`** value (scheme + host + any path, no trailing slash surprises).

**2. Set it explicitly in Duende** so it no longer depends on how the request arrives:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.example.com"; // exactly match the old issuer
});
```

**3. Make the proxy present the right host/scheme.** Behind nginx, configure `UseForwardedHeaders` (and forward `X-Forwarded-Proto`/`X-Forwarded-Host`) so ASP.NET Core sees the correct external HTTPS URL. Even with an explicit `IssuerUri`, you want redirect URIs, endpoints, and cookie behavior to reflect the public URL — otherwise the discovery document can advertise `http://…` or an internal host.

**4. Verify after cutover.** Compare the new `/.well-known/openid-configuration` `issuer` against the old one — they must be **identical**.

## Bottom line

Keep the issuer URI **identical** across the migration. Read it from your current discovery document, set `options.IssuerUri` explicitly in Duende to that value, and configure forwarded headers so the new Kestrel/nginx hosting doesn't inadvertently change it.
