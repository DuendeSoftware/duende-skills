# Adding an Audience Claim to Access Tokens

If your tokens don't have an `aud` claim and you want one without the complexity of API Resources, you have a couple of options.

## Option 1: Define an API Resource

The standard way to get an `aud` claim is to define an `ApiResource`:

```csharp
public static IEnumerable<ApiResource> ApiResources =>
[
    new ApiResource("myapi")
    {
        Scopes = { "api1" }
    }
];
```

Register it:
```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

This will add `"aud": "myapi"` to tokens that include the `api1` scope.

## Option 2: Custom Claims in a Profile Service

You could implement a custom `IProfileService` to add an audience claim manually, though this is more complex and non-standard.

## Recommendation

Even for a single API, defining an `ApiResource` is straightforward and gives you proper audience validation. It's the recommended approach.
