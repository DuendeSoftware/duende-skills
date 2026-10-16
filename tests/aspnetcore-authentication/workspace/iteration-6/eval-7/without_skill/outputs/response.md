Options, roughly in order of preference:

1. **Don't store what you don't need.**
   - Set `SaveTokens = false` if you don't call APIs, or only save what's needed (e.g. drop the id_token or access token and fetch later).
   - Set `GetClaimsFromUserInfoEndpoint = false` or use `ClaimActions.DeleteClaim(...)` / `options.ClaimActions.Remove...` to filter unneeded claims, and request fewer scopes.
   - Remove unused claims in `OnTokenValidated`.

2. **Server-side session store** – keep the cookie small by using `SessionStore` (`ITicketStore`) with a distributed cache/DB; the cookie holds just a session id.

```csharp
public class CacheTicketStore(IDistributedCache cache) : ITicketStore
{
    public async Task<string> StoreAsync(AuthenticationTicket t)
    {
        var key = Guid.NewGuid().ToString();
        await RenewAsync(key, t);
        return key;
    }
    public Task RenewAsync(string key, AuthenticationTicket t)
    {
        var bytes = TicketSerializer.Default.Serialize(t);
        return cache.SetAsync(key, bytes, new DistributedCacheEntryOptions { SlidingExpiration = TimeSpan.FromHours(8) });
    }
    public async Task<AuthenticationTicket?> RetrieveAsync(string key)
    {
        var b = await cache.GetAsync(key);
        return b is null ? null : TicketSerializer.Default.Deserialize(b);
    }
    public Task RemoveAsync(string key) => cache.RemoveAsync(key);
}

builder.Services.AddSingleton<ITicketStore, CacheTicketStore>();
builder.Services.AddOptions<CookieAuthenticationOptions>("Cookies")
    .Configure<ITicketStore>((o, store) => o.SessionStore = store);
```

Or use a library such as Duende.AccessTokenManagement / Duende BFF, which stores tokens server-side.

3. **Chunking** – ASP.NET Core already splits cookies into chunks (`.AspNetCore.Cookies` `C1`, `C2`), but browsers and proxies limit total header size, so this is only a stopgap.

4. Alternatively, store the tokens in a token store keyed by user (e.g. `IUserTokenStore`) rather than in the cookie.
