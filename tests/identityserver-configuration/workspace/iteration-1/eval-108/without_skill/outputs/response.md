# Adding an Audience Claim

The easiest way to get an audience claim is to define an API Resource:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("api1")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("api1")
        {
            Scopes = { "api1" }
        }
    });
```

The API Resource name becomes the `aud` claim in the token. Then your API validates it:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
    });
```
