# Migrating `ICache<Client>` to v8

I'm not certain of the exact v8 replacement, so confirm against the release notes. This is the approach I'd take.

- The v7 `ICache<T>` abstraction (`GetOrAddAsync`, `Get`, `Set`, `Remove`) is IdentityServer's internal caching abstraction. In newer versions Duende has been moving toward the standard .NET caching abstractions, such as `HybridCache` or `IMemoryCache`/`IDistributedCache`. If `ICache<T>` is removed or changed, you would implement against one of those instead.
- **Lifetime.** Caches should be singletons, because a transient cache holds no state across requests. Yours is a pass-through, so that didn't matter, but a real cache needs `AddSingleton`.

```csharp
builder.Services.AddSingleton<ICache<Client>, CustomClientCache>(); // if the interface remains
```

If you only wanted to cache clients, the simplest approach is to use the built-in support:
```csharp
.AddInMemoryClients(...)
.AddInMemoryCaching()
.AddClientStoreCache<CustomClientStore>();
```
This removes the need for a custom cache. Tune `options.Caching.ClientStoreExpiration`.

Rebuild after bumping packages. The compiler errors will show exactly which members changed.
