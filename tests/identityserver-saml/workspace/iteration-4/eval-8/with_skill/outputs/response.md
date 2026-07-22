# Configuring a SAML Service Provider and Resolving Validation Errors

## Background

Duende IdentityServer automatically wraps every SP store with a `ValidatingSamlServiceProviderStore<T>`. Any SP that fails validation is treated as **non-existent** — requests from it will be rejected as if the SP were not registered at all. Understanding the validation rules upfront prevents hard-to-diagnose failures.

---

## Common Validation Requirements

### 1. `EntityId` — Required, Non-Empty

The SP entity ID must be a non-empty string. It must **exactly match** what the SP sends in its `<AuthnRequest>` (case-sensitive URI comparison).

```csharp
EntityId = "https://hr.example.com"  // must match the SP's Issuer element exactly
```

### 2. At Least One ACS URL — **HTTP-POST Binding Only**

The `AssertionConsumerServiceUrls` collection must contain **at least one** entry, and every entry **must use `SamlBinding.HttpPost`**. HTTP-Redirect is not supported for ACS and will fail validation.

```csharp
AssertionConsumerServiceUrls =
[
    new IndexedEndpoint
    {
        Location = "https://hr.example.com/sso",  // the ACS URL
        Binding   = SamlBinding.HttpPost,          // MUST be HttpPost — Redirect fails validation
        Index     = 0,
        IsDefault = true
    }
]
```

> ❌ **Common mistake:** Setting `Binding = SamlBinding.HttpRedirect` on an ACS URL. Only HTTP-POST is valid for AssertionConsumerServiceUrls.

### 3. At Least One `AllowedScopes` Entry

The `AllowedScopes` collection must be non-empty. This controls which identity resources (and therefore which claims) the SP can receive. An SP with no allowed scopes will pass no claims in its assertion — a silent misconfiguration that is caught at validation time.

```csharp
AllowedScopes = ["openid", "profile", "email"]  // at least one entry required
```

> ❌ **Common mistake:** Omitting `AllowedScopes` entirely. The SP gets registered but no claims are ever included in the assertion.

### 4. Positive Lifetimes

Any lifetime overrides must be positive (greater than zero). The following properties are checked:

- `AssertionLifetime` — if set, must be > `TimeSpan.Zero`

```csharp
AssertionLifetime = TimeSpan.FromMinutes(5)  // positive value required if set
```

---

## Complete Valid Configuration for `https://hr.example.com`

Starting from your existing `Program.cs` (OIDC-only), here is the full configuration:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Saml;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);  // <-- add SAML SPs

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

And in `Config.cs`, add the `SamlServiceProviders` collection:

```csharp
public static IEnumerable<SamlServiceProvider> SamlServiceProviders =>
[
    new SamlServiceProvider
    {
        // Required: entity ID must match what the SP sends in its AuthnRequest Issuer
        EntityId    = "https://hr.example.com",
        DisplayName = "HR System",

        // Required: at least one ACS URL with HttpPost binding
        AssertionConsumerServiceUrls =
        [
            new IndexedEndpoint
            {
                Location  = "https://hr.example.com/sso",
                Binding   = SamlBinding.HttpPost,   // MUST be HttpPost
                Index     = 0,
                IsDefault = true
            }
        ],

        // Required: at least one scope so claims flow to the SP
        AllowedScopes = ["openid", "profile", "email"],

        // Optional: map OIDC claim names to SAML attribute URIs
        ClaimMappings = new Dictionary<string, string>
        {
            ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
            ["name"]  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
        },

        // Optional: NameID format (EmailAddress is common for HR systems)
        DefaultNameIdFormat = SamlNameIdFormat.EmailAddress,

        // Optional: signing behavior (SignAssertion is default; SignResponse is more interoperable)
        SigningBehavior = SamlSigningBehavior.SignAssertion,

        // Optional: single logout
        SingleLogoutServiceUrls =
        [
            new SamlEndpointType
            {
                Location = "https://hr.example.com/slo",
                Binding  = SamlBinding.HttpRedirect  // SLO supports HttpRedirect
            }
        ],

        Enabled = true
    }
];
```

---

## Validation Error Diagnostics

If your SP is being silently rejected, check the following:

### Check the IdentityServer Logs

The `ValidatingSamlServiceProviderStore` logs a warning when an SP fails validation. Look for log entries at the `Warning` level from `Duende.IdentityServer` mentioning the entity ID.

Set your minimum log level to `Debug` during troubleshooting:

```json
{
  "Logging": {
    "LogLevel": {
      "Duende.IdentityServer": "Debug"
    }
  }
}
```

### Validation Rules Checklist

| Rule | What to check |
|---|---|
| EntityId required | Is `EntityId` set to a non-empty string? |
| ≥1 ACS URL | Does `AssertionConsumerServiceUrls` have at least one entry? |
| ACS HTTP-POST only | Is every ACS entry using `SamlBinding.HttpPost`? |
| ≥1 AllowedScopes | Does `AllowedScopes` have at least one scope name? |
| Positive lifetimes | If `AssertionLifetime` is set, is it > `TimeSpan.Zero`? |

---

## Common Additional Issues (Beyond Validation)

Even after passing validation, you may see errors from specific SPs:

| Error | Likely Cause | Fix |
|---|---|---|
| SP reports "issuer mismatch" | IdentityServer's `EntityId` doesn't match what the SP has configured as IdP issuer | Set `saml.EntityId` in `SamlOptions` to match exactly |
| SP reports "signature verification failed" | SP has a different signing cert configured | Ensure the SP's metadata matches IdentityServer's published cert at `/Saml2` |
| SP reports "ACS URL not allowed" | SP sends an ACS URL in the AuthnRequest that doesn't match any registered `AssertionConsumerServiceUrls` | Add the exact URL the SP sends to `AssertionConsumerServiceUrls` |
| SP reports "response not yet valid" | Clock skew between IdP and SP | Increase `saml.DefaultClockSkew` (default is 5 minutes) |
| SP gets no claims in assertion | `AllowedScopes` doesn't include a resource containing the desired claim types | Add the relevant identity resource scope to `AllowedScopes` and ensure `ClaimMappings` maps it |
