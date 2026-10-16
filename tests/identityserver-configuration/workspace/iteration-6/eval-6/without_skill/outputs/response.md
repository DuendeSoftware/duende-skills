```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource
        {
            Name = "organization",
            DisplayName = "Your organization",
            Required = true,
            UserClaims = { "org_id", "org_name", "org_role" }
        }
    });
```
`Required = true` means the user can't deselect it on the consent page. Clients must still list `organization` in `AllowedScopes`.
