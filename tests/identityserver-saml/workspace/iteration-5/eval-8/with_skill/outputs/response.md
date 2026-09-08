# SAML Service Provider Validation Requirements

Duende IdentityServer runs every SAML service provider through an automatic validation layer before it's ever used. Whatever store you register (in-memory, EF Core, or custom `ISamlServiceProviderStore`) is transparently wrapped by **`ValidatingSamlServiceProviderStore<T>`**. If an SP fails any check, it is **treated as non-existent** — the store returns `null` rather than surfacing a detailed error, so from the SAML endpoint's perspective the SP simply doesn't exist.

That "treated as non-existent" behavior is exactly why you can see confusing failures: a misconfigured SP looks identical to an unregistered one.

## The checks that must pass

For your SP with EntityId `https://hr.example.com` and ACS URL `https://hr.example.com/sso`:

1. **EntityId is required.** It must be present and non-empty. `https://hr.example.com` is fine.

2. **At least one ACS URL, and ACS must use HTTP-POST binding.** Assertion Consumer Service URLs support **HTTP-POST only**. If you configured `https://hr.example.com/sso` with `SamlBinding.HttpRedirect`, it will fail validation — HTTP-Redirect is **not** supported for ACS. Use `SamlBinding.HttpPost`.

3. **At least one `AllowedScopes` entry.** An empty `AllowedScopes` fails validation (and would mean the SP receives no claims anyway). Include at least one, e.g. `["openid", "profile", "email"]`.

4. **Positive lifetime values.** Assertion/message lifetimes must be positive (greater than zero). A zero or negative `AssertionLifetime` fails validation.

## A correctly configured SP for `hr.example.com`

```csharp
new SamlServiceProvider
{
    EntityId = "https://hr.example.com",          // required, non-empty
    DisplayName = "HR System",

    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://hr.example.com/sso",
            Binding = SamlBinding.HttpPost,          // MUST be HTTP-POST, not HttpRedirect
            Index = 0,
            IsDefault = true
        }
    ],

    AllowedScopes = ["openid", "profile", "email"], // at least one entry required

    AssertionLifetime = TimeSpan.FromMinutes(5)      // positive lifetime
}
```

## Most likely cause of your errors

Given a name like `/sso`, the classic mistake is configuring the ACS with **HTTP-Redirect** — that's the single most common validation failure. Switch it to `SamlBinding.HttpPost`. The second most common is an **empty `AllowedScopes`**. Fix both and the SP will resolve instead of returning `null`.

> Tip: because invalid SPs return `null` (as if unregistered), don't chase "SP not found" errors as a lookup problem first — verify the four validation requirements above.
