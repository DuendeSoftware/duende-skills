# Cookie Size Too Large

When your authentication cookie exceeds 4KB, browsers silently truncate or reject it. Here are options:

## Solutions

1. **Use chunked cookies** — ASP.NET Core can chunk large cookies across multiple cookies using `ChunkingCookieManager`, but this has its own limits.

2. **Filter claims** — Remove unnecessary claims before they're stored:
```csharp
options.ClaimActions.DeleteClaim("sid");
options.ClaimActions.DeleteClaim("amr");
```

3. **Use session store** — Store the authentication ticket server-side using a distributed cache:
```csharp
builder.Services.AddDistributedMemoryCache();
```

4. **Reduce token size** — Consider whether you really need `SaveTokens = true`. If you're not making API calls from the web app, you may not need the tokens stored.

The `SaveTokens = true` setting stores all tokens (access, refresh, ID) in the cookie, which is typically the largest contributor to size.
