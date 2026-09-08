# Token Caching in Duende.AccessTokenManagement

## What gets cached

For the **client credentials** flow, the library caches the access token it obtains from the token endpoint and reuses it until it's close to expiry, then requests a fresh one. This avoids hitting the token endpoint on every outgoing call. **User** tokens obtained via OpenID Connect are stored in the authentication session (the cookie, when `SaveTokens = true`) and refreshed using the refresh token when they expire.

## The cache backend

Client-credential token caching is built on ASP.NET Core's caching abstraction (`IDistributedCache`). That means:

- **In-memory (default / single instance):** register an in-memory distributed cache:

  ```csharp
  builder.Services.AddDistributedMemoryCache();
  ```

- **Distributed (multi-instance):** register a shared backend such as Redis so all instances share cached tokens:

  ```csharp
  builder.Services.AddStackExchangeRedisCache(options =>
  {
      options.Configuration = builder.Configuration.GetConnectionString("Redis");
  });
  ```

Because it uses the standard cache abstraction, you can point it at whatever `IDistributedCache` implementation your deployment uses.

## Controlling refresh timing

You can configure how early a token is refreshed relative to its expiry using a lifetime buffer, so you never serve a token that's about to expire:

```csharp
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60; // refresh ~60s before the token actually expires
});
```

## Summary

- Client credentials tokens are cached and reused until near expiry, then re-requested.
- Caching uses the ASP.NET Core cache abstraction — in-memory for a single instance, or a distributed cache like Redis for multiple instances.
- `CacheLifetimeBuffer` controls how far ahead of expiry a token is refreshed.

> Caching internals can change between major versions, so if you're on the latest version, check the current documentation for the exact default cache and whether any explicit cache registration is still required.
