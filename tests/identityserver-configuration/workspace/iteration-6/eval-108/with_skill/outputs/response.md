Use `EmitStaticAudienceClaim`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryApiScopes(new[] { new ApiScope("api1") })
    // ...
```
With only API Scopes, tokens have no `aud`. This option adds `aud: "{issuer}/resources"` (e.g. `https://identity.example.com/resources`), and your API validates that value as `ValidAudience`.

Caveats: the audience is generic — the same for every API — so it doesn't provide audience isolation. If you later add a second API, or want a meaningful audience such as `aud: "my-api"`, switch to an `ApiResource` (it's only a few lines):

```csharp
new ApiResource("my-api") { Scopes = { "api1" } }
```
registered with `.AddInMemoryApiResources(...)`. That yields `aud: "my-api"` and is the better long-term approach.
