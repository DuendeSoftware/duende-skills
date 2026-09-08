The 4KB limit is per-cookie; when you exceed it ASP.NET Core chunks the cookie (`myapp`, `myappC1`, `myappC2`, …), and beyond a few KB you start hitting total header limits, proxy limits, and performance problems. With `SaveTokens = true` **plus** a full set of userinfo claims, you're storing a lot in the client. You have three complementary options.

### Where the size comes from

`SaveTokens = true` serializes the **access token, refresh token, and ID token** into the authentication ticket, which is then encrypted into the cookie. Add every claim returned from the userinfo endpoint and the ticket balloons. So the fixes are: (a) stop storing the ticket in the cookie, (b) store fewer claims, or (c) move session state server-side.

### Solution 1 — Move the ticket server-side with `ITicketStore`

Keep only a small session key in the cookie and store the actual ticket (tokens + claims) in a distributed cache:

```csharp
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "localhost:6379");
builder.Services.AddSingleton<ITicketStore, RedisTicketStore>(); // your IDistributedCache-backed impl

builder.Services
    .AddOptions<CookieAuthenticationOptions>("Cookies")
    .Configure<ITicketStore>((options, store) => options.SessionStore = store);
```

`ITicketStore` (in `Microsoft.AspNetCore.Authentication.Cookies`) stores the serialized `AuthenticationTicket` in Redis/SQL/etc. and the cookie holds just the key — so cookie size becomes constant regardless of how many claims or tokens you carry. There is no built-in distributed implementation; you implement `StoreAsync`/`RetrieveAsync`/`RenewAsync`/`RemoveAsync` over `IDistributedCache`.

### Solution 2 — Filter out unnecessary claims

Drop claims you never read (IdentityServer emits several protocol claims you rarely need in the cookie):

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.ClaimActions.DeleteClaims("sid", "idp", "auth_time", "amr", "s_hash");
    // and/or add only the specific claims you actually use
});
```

This shrinks the claims portion of the ticket directly.

### Solution 3 — Duende IdentityServer server-side sessions

Enable **server-side sessions** in IdentityServer so session/claim state lives on the server, which reduces what the client app needs to persist and enables features like session management and back-channel logout. Combined with only storing what you need in the app, this keeps the cookie small.

### Recommendation

For a robust production setup, use **Solution 1 (`ITicketStore` over a distributed cache)** as the primary fix — it makes cookie size independent of claim/token count — and layer in **Solution 2** to avoid persisting claims you don't use. If you also control IdentityServer, **server-side sessions (Solution 3)** is the most complete approach. If you don't actually need the stored tokens in the app, you can also set `SaveTokens = false` (or better, use `Duende.AccessTokenManagement`, which keeps tokens out of the cookie).
