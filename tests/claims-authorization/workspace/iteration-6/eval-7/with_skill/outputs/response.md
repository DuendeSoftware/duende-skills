# Static claims on `billing-service`

Add `ClientClaim`s to the client definition and clear the `client_` prefix.

```csharp
new Client
{
    ClientId = "billing-service",
    ClientName = "Billing Service",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },

    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east"),
    },

    // Default prefix is "client_" (client_customer_id, client_region).
    // Empty string emits customer_id and region. Use carefully.
    ClientClaimsPrefix = ""
}
```

Without the prefix override the token contains `client_customer_id` and `client_region`. The prefix exists to prevent collisions with user claims, so with `""` avoid names such as `sub` or `name`.

Notes:
- In the **client credentials flow** client claims are emitted by default. For other flows set `AlwaysSendClientClaims = true`.
- For values computed at runtime, implement `ICustomTokenRequestValidator`:
```csharp
public sealed class DynamicClientClaimsValidator(IClientContextService ctx) : ICustomTokenRequestValidator
{
    public async Task ValidateAsync(CustomTokenRequestValidationContext context)
    {
        if (context.Result.ValidatedRequest.GrantType != GrantType.ClientCredentials) return;
        var tier = await ctx.GetSubscriptionTierAsync(context.Result.ValidatedRequest.Client.ClientId);
        context.Result.ValidatedRequest.ClientClaims.Add(new Claim("subscription_tier", tier));
    }
}
```
  Register with `.AddCustomTokenRequestValidator<DynamicClientClaimsValidator>()`.
- No user exists in client credentials, so the profile service isn't involved.
- Verify by requesting a token and decoding it.
