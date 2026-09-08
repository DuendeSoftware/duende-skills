# Diagnosing "claim in userinfo but missing from the id_token"

Don't rewrite your `IProfileService` — this is almost certainly working as designed. In Duende IdentityServer the **id_token is deliberately minimal by default**, so profile claims like `department` are expected at the userinfo endpoint, not embedded in the id_token.

## Why this is expected behavior

`GetProfileDataAsync` is called separately for each token type via `context.Caller`. For the id_token it is invoked as `ClaimsProviderIdentityToken` **with `includeAllIdentityClaims = false`**, which is why the id_token comes out lean. The same claim *is* returned when the caller is `UserInfoEndpoint` — which is exactly what you're seeing at `/connect/userinfo`. So the claim is being issued correctly; it's just routed to userinfo rather than the id_token.

## How to diagnose (before touching the profile service)

1. **Confirm it's at userinfo** — you already have. That alone tells you issuance is fine and this is a token-shape/consumption question, not a profile-service bug.
2. **Turn on `Duende.IdentityServer` debug logging.** The default profile service logs the **requested vs. issued claim types** for each call. This shows you, per caller, that `department` is being requested and issued for the access-token/userinfo path — confirming nothing is being silently filtered out.

```json
// appsettings.json
{
  "Logging": {
    "LogLevel": {
      "Duende.IdentityServer": "Debug"
    }
  }
}
```

## The fix — get the claim into your web app's principal

You have two options on the **client** side (the ASP.NET Core OIDC handler in your web app):

**Preferred: fetch from userinfo.** Have the OIDC handler call the userinfo endpoint after login and merge those claims into the principal:

```csharp
builder.Services.AddAuthentication(...)
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://identity.example.com";
        // Pull profile claims (like department) from /connect/userinfo
        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens = true;

        options.MapInboundClaims = false;
        options.ClaimActions.MapJsonKey("department", "department");
    });
```

**Alternative: embed in the id_token.** Set `AlwaysIncludeUserClaimsInIdToken = true` on the client so all user claims go into the id_token directly — but this **increases id_token size** (can hit cookie/header limits) and caches the claims in the token until it expires:

```csharp
new Client
{
    ClientId = "webapp",
    AlwaysIncludeUserClaimsInIdToken = true,   // ⚠️ larger id_token, staleness tradeoff
    // ...
};
```

## Bottom line

- The claim is **not** missing from issuance — it's present at userinfo, which is where the minimal-id_token design puts it.
- Fix it on the client with `GetClaimsFromUserInfoEndpoint = true` (recommended), or `AlwaysIncludeUserClaimsInIdToken = true` to embed it (at the cost of token size).
- Use `Duende.IdentityServer` debug logging (requested vs. issued claim types) to confirm the diagnosis before editing the profile service.
