# Custom Identity Resource

You can define a custom identity resource for organization claims:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource
        {
            Name = "organization",
            DisplayName = "Organization Info",
            UserClaims = { "org_id", "org_name", "org_role" }
        }
    });
```

This creates a custom scope called `organization` that returns the three claims when requested. Clients can request this scope alongside `openid` and `profile`.

To populate these claims, you'll need to implement `IProfileService` or configure them in your user store.
