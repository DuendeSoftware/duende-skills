# Why `department` is at `/connect/userinfo` but not in the id_token

Good news: you don't need to rewrite your `IProfileService`. The fact that `department` shows up at the userinfo endpoint tells you the claim **is** being issued correctly. This is expected OIDC/IdentityServer behavior, not a bug.

## What's actually happening

By default IdentityServer keeps the **id_token small**. User profile claims are not embedded in the id_token; instead they are made available at the **userinfo endpoint**, which the client fetches separately. So a claim being present at `/connect/userinfo` but absent from the id_token is the normal, intended split.

## How to diagnose

- You've already confirmed the claim is returned by `/connect/userinfo` — that's the key signal that issuance and your profile service are fine.
- Decode the id_token and confirm the profile claims genuinely aren't there (they won't be, by default).
- Since the claim exists at userinfo, the "fix" is about getting your **web app** to pick it up, not about the token server.

## The fix (on the client OIDC handler)

Enable the OIDC handler to call the userinfo endpoint and merge those claims into the user principal:

```csharp
builder.Services.AddAuthentication(...)
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://identity.example.com";
        options.GetClaimsFromUserInfoEndpoint = true;  // pull department etc. from userinfo
        options.SaveTokens = true;
    });
```

If you specifically need the claim **inside** the id_token itself (for example, a client that can't call userinfo), set `AlwaysIncludeUserClaimsInIdToken = true` on the client. Be aware this makes the id_token larger and can push you toward cookie/header size limits, so prefer the userinfo approach when you can.

```csharp
new Client
{
    ClientId = "webapp",
    AlwaysIncludeUserClaimsInIdToken = true, // embeds profile claims in id_token (bigger token)
    // ...
};
```

## Summary

- The claim isn't missing from issuance — it's at userinfo because the id_token is minimal by default.
- Use `GetClaimsFromUserInfoEndpoint = true` on the client to surface it, or `AlwaysIncludeUserClaimsInIdToken = true` to embed it in the id_token (with a size tradeoff).
