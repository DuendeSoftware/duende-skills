# Custom NameID Values from an Employee ID Claim in SAML

To generate custom NameID values using an `employee_id` claim instead of the default `sub` claim, you'll need to customize the SAML response generation in your IdentityServer configuration.

## Overview

In Duende IdentityServer with SAML support, the NameID value in the SAML assertion is typically derived from the user's subject (`sub`) claim. To use a different claim like `employee_id`, you need to:

1. Ensure the `employee_id` claim is available on the user's identity
2. Configure the SAML service provider to use that claim as the NameID source
3. Optionally customize the NameID format

## Step 1: Make the `employee_id` Claim Available

Your users (currently configured via `AddTestUsers`) need to have the `employee_id` claim included in their claims collection. In the reference `Program.cs`, test users would need to be updated:

```csharp
new TestUser
{
    SubjectId = "1",
    Username = "alice",
    Password = "alice",
    Claims =
    {
        new Claim("name", "Alice"),
        new Claim("email", "alice@example.com"),
        new Claim("employee_id", "EMP-001")  // Add this
    }
}
```

## Step 2: Create an Identity Resource for the Claim

You need to expose `employee_id` as part of an identity resource so it can be included in tokens and SAML assertions:

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email(),
    new IdentityResource("employee_profile", new[] { "employee_id" })
    {
        DisplayName = "Employee Profile"
    }
];
```

## Step 3: Configure the SAML SP to Use `employee_id` as NameID

When registering the SAML Service Provider, configure the `NameIdClaimType` to point to the `employee_id` claim:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSamlPlugin(options =>
    {
        options.Licensee = "YOUR_LICENSEE";
        options.LicenseKey = "YOUR_LICENSE_KEY";
    })
    .AddInMemoryServiceProviders(Config.ServiceProviders);
```

In your SP configuration:

```csharp
public static IEnumerable<Duende.IdentityServer.Saml.Models.ServiceProvider> ServiceProviders =>
[
    new ServiceProvider
    {
        EntityId = "https://your-sp.example.com",
        AssertionConsumerServices =
        {
            new AssertionConsumerService
            {
                Binding = Saml2Constants.ProtocolBindings.HttpPost,
                Location = new Uri("https://your-sp.example.com/acs")
            }
        },
        // Map the NameID to the employee_id claim
        ClaimsMapping = new Dictionary<string, string>
        {
            // Map outgoing NameID to the employee_id claim value
        },
        // Specify which claim type to use for the NameID
        NameIdClaimType = "employee_id",
        // Optionally specify NameID format
        NameIdFormat = Saml2Constants.NameIdentifierFormats.Persistent
    }
];
```

## Step 4: Implement a Custom IProfileService (if needed)

If the `employee_id` claim isn't automatically included, implement a custom profile service to ensure it's emitted:

```csharp
public class CustomProfileService : IProfileService
{
    public Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Retrieve employee_id from your user store
        var employeeId = GetEmployeeIdForUser(context.Subject.GetSubjectId());

        context.IssuedClaims.Add(new Claim("employee_id", employeeId));

        return Task.CompletedTask;
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

Register it:

```csharp
builder.Services.AddTransient<IProfileService, CustomProfileService>();
```

## Common NameID Formats

| Format | URI Constant | Use Case |
|--------|-------------|----------|
| Persistent | `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent` | Stable, opaque identifier |
| Transient | `urn:oasis:names:tc:SAML:2.0:nameid-format:transient` | Session-only, randomized |
| Email | `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress` | Email as identifier |
| Unspecified | `urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified` | No specific format required |

## Notes

- The `employee_id` claim must be consistently available for all users who will authenticate via SAML — if some users lack this claim, SAML assertions will fail or produce empty NameIDs.
- Ensure the SP you're integrating with accepts the NameID format you configure.
- If the SP sends a specific `NameIDPolicy` in its `AuthnRequest`, your IdP configuration must be compatible with it.
