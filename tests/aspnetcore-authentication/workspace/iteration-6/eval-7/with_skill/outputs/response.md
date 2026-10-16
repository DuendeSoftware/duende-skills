Large cookies come from `SaveTokens = true` plus lots of userinfo claims. Options:

### 1. Server-side ticket store (`ITicketStore`)
The cookie holds only a session key; the ticket lives in e.g. Redis. There's no built-in store, so implement `ITicketStore` (namespace `Microsoft.AspNetCore.Authentication.Cookies`) on `IDistributedCache`:

```csharp
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "localhost:6379");
builder.Services.AddSingleton<ITicketStore, RedisTicketStore>(); // your implementation

builder.Services.AddOptions<CookieAuthenticationOptions>("Cookies")
    .Configure<ITicketStore>((o, store) => o.SessionStore = store);
```

(Avoid resolving from `app.Services` while configuring; the options-configure approach above does the same wiring safely.)

### 2. Filter claims stored in the cookie
```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.ClaimActions.DeleteClaims("sid", "idp", "auth_time", "amr");
});
```
Also request only the scopes/claims you need, and consider `SaveTokens = false` if you don't call APIs.

### 3. Duende IdentityServer server-side sessions
Server-side sessions (see `identityserver-sessions-providers`) keep session data on the IdP side.

### 4. Token management
Use `Duende.AccessTokenManagement` for refresh/caching of tokens instead of manually keeping them in the cookie.
