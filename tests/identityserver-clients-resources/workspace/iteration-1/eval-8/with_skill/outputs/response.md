# Getting an Audience Claim Without API Resources

The simplest way to get an `aud` claim in your tokens without defining full API Resources is to enable `EmitStaticAudienceClaim` in the IdentityServer options.

## Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

## What This Does

When `EmitStaticAudienceClaim = true`, IdentityServer emits a static audience claim with the value `{issuer}/resources` in all access tokens. For example, if your issuer is `https://identity.example.com`, tokens will contain:

```json
{
  "aud": "https://identity.example.com/resources",
  "scope": "api1"
}
```

## Alternative: Define a Minimal ApiResource

For a more targeted approach, you can define an `ApiResource` that references your scope:

```csharp
public static IEnumerable<ApiResource> ApiResources =>
[
    new ApiResource("myapi")
    {
        Scopes = { "api1" }
    }
];
```

This would produce an `aud` claim of `"myapi"` instead of the generic `{issuer}/resources`. This is preferred when you want a specific, meaningful audience value, especially if you plan to add more APIs later.

## When to Use Which

- **`EmitStaticAudienceClaim`**: Quick fix for a single API that just needs an `aud` claim. All tokens get the same audience.
- **`ApiResource`**: Better for long-term architecture. Gives you a specific audience value and prepares you for multi-API scenarios with audience isolation.
