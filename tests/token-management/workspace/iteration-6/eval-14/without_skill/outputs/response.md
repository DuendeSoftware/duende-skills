# Why `dpop_jkt` disappears

The OpenID Connect token management package configures `OpenIdConnectOptions` through its own `IPostConfigureOptions`/configure step. When DPoP is enabled it hooks `options.Events.OnAuthorizationCodeReceived` / `OnRedirectToIdentityProvider` to add the `dpop_jkt` parameter (the thumbprint of the DPoP key) to the authorization request. When you assign `options.Events = new OpenIdConnectEvents { ... }` in your own post-configure, you **replace** the whole events object, so the library's handlers are dropped and `dpop_jkt` is no longer added. With JAR/PAR, your handler also builds the signed request object and pushes it, so the parameter must be included *before* signing.

## Fix

Don't replace `Events`; chain onto the existing handlers.

```csharp
builder.Services.AddOptions<OpenIdConnectOptions>("oidc").PostConfigure<IDPoPKeyStore>((options, keys) =>
{
    var previous = options.Events.OnRedirectToIdentityProvider;
    options.Events.OnRedirectToIdentityProvider = async ctx =>
    {
        if (previous != null) await previous(ctx);   // keeps dpop_jkt

        // make sure dpop_jkt is in the parameters, then sign the request object (JAR)
        // and push (PAR)
        ctx.ProtocolMessage.Parameters.TryGetValue("dpop_jkt", out var jkt);
        // ... build/sign request object including dpop_jkt
    };
});
```

Also, if you wrap `OnPushAuthorization`, call the original first or ensure `dpop_jkt` is included in the signed request object (when using JAR it must be inside the JWT).
