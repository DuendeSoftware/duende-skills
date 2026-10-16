Set `EmitStaticAudienceClaim` — it adds an `aud` claim of `{issuer}/resources`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
.AddInMemoryApiScopes(new[] { new ApiScope("api1") });
```
Your API then validates audience `https://your-issuer/resources`. Alternatively, a single `ApiResource("api1")` with `Scopes = { "api1" }` gives `aud: api1`, and is only a few lines — which is typically the better long-term choice.
