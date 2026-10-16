# UseCacheAutoTuning

I'm not fully certain of this from memory, but my understanding is: it is a property of `ClientCredentialsTokenManagementOptions` and **defaults to `true`**. When enabled, the library adjusts the cache entry lifetime based on the token's actual `expires_in` instead of a fixed default — i.e. it sets the cache duration to token lifetime minus the `CacheLifetimeBuffer` (default 60 s), so entries expire shortly before the token does.

```csharp
services.AddClientCredentialsTokenManagement(o =>
{
    o.UseCacheAutoTuning = true;   // default
    o.CacheLifetimeBuffer = 60;
});
```
Set it to `false` only if you want to manage cache lifetime yourself.
