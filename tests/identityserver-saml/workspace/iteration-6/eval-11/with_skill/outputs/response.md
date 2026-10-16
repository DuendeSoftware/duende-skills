# Duende Storage extended properties on SAML SPs

**No — not the way you're hoping.** With Duende Storage (`AddStorage(...)` + `AddConfigurationStorage()`), data-extension properties on a SAML service provider are **admin-only metadata**. They are stored through `ISamlServiceProviderAdmin` (alongside `SamlServiceProviderConfiguration`), but they are **not projected onto the runtime `SamlServiceProvider`** that the SAML pipeline works with. So `owner_team` won't be visible on the SP object when you build the assertion.

## What to do instead

- **Look it up yourself** keyed on `EntityId`: read the extension through the admin/storage API (or your own table) from within a custom component, e.g. an `ISaml2SsoResponseGenerator` or a claims/profile step, and cache it.
- **Put it in the claim pipeline**: if the value is really about the user/SP relationship, emit it as a claim from `IProfileService` (using `context.RequestedResources`/the caller) and map it with `ClaimMappings` (`AllowedScopes` → `RequestedClaimTypes` → `ClaimMappings`). Make sure the owning identity resource is in the SP's `AllowedScopes`.
- **Custom `ISamlServiceProviderStore`** if you need the data on the runtime model's side: wrap your own storage and resolve it in your own services.

Also note: your current Program.cs hasn't called `.AddSaml()` yet; add it first. And the default `ISamlSigninStateSerializer` ignores `Extensions`, so don't rely on state `Extensions` surviving the round-trip without a custom serializer.
