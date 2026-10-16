# Why `dpop_jkt` disappears, and how to fix it

## Cause

`AddOpenIdConnectAccessTokenManagement` registers an `IConfigureNamedOptions<OpenIdConnectOptions>` that **wraps** the OIDC handler events: your handler runs first, then the library's. DPoP depends on those library handlers:

| Event | What the library does |
|---|---|
| `OnRedirectToIdentityProvider` | adds `dpop_jkt` to the authorize request and stores the DPoP key in the authentication properties |
| `OnAuthorizationCodeReceived` | makes the DPoP key available for the code exchange; adds the client assertion if configured |
| `OnTokenValidated` | reserved for DPoP key handling |
| `OnPushAuthorization` | adds the client assertion to the PAR request (.NET 9+) |

If your `IPostConfigureOptions<OpenIdConnectOptions>` (or `PostConfigure`) assigns `options.Events = new OpenIdConnectEvents { ... }`, or overwrites a handler such as `OnRedirectToIdentityProvider`, it runs after the library's configuration and **discards those handlers**. Sign-in still works, but `dpop_jkt` is no longer sent and the code isn't exchanged with the DPoP key.

The same happens if you set `OpenIdConnectOptions.EventsType`. ASP.NET Core then uses that type instead of `Events`, silently removing all library handlers.

## Fix: wrap, don't replace

Capture the existing handler, call it, and add your logic around it. Never assign a new `OpenIdConnectEvents` and never use `EventsType`.

The order matters with JAR:

- **Without PAR:** wrap `OnRedirectToIdentityProvider`. Call the library's handler first so `dpop_jkt` is added. Then sign all parameters into the request object, keeping `client_id` and `redirect_uri` as plain parameters.
- **With PAR (.NET 9+):** wrap `OnPushAuthorization`. Sign all parameters first (including `dpop_jkt`), then call the library's handler so it adds the `private_key_jwt` client assertion.

```csharp
builder.Services.AddOpenIdConnectAccessTokenManagement(options =>
{
    options.DPoPJsonWebKey = jwk;      // stable key, loaded from secure config
});

builder.Services.AddOptions<OpenIdConnectOptions>("oidc")
    .PostConfigure<IRequestObjectSigner>((options, signer) =>
    {
        // ✅ capture what the library already configured
        var originalRedirect = options.Events.OnRedirectToIdentityProvider;
        var originalPush = options.Events.OnPushAuthorization;

        options.Events.OnRedirectToIdentityProvider = async ctx =>
        {
            // library first: adds dpop_jkt
            if (originalRedirect is not null)
                await originalRedirect(ctx);

            // Sign here ONLY when PAR is not used. With
            // PushedAuthorizationBehavior.UseIfAvailable this handler is still the
            // fallback if discovery has no PAR endpoint.
            if (!ParIsUsed(ctx))
                ctx.ProtocolMessage = signer.CreateSignedRequest(ctx.ProtocolMessage); // JAR
        };

        options.Events.OnPushAuthorization = async ctx =>
        {
            // sign ALL parameters, including dpop_jkt, BEFORE the library adds the assertion
            ctx.ProtocolMessage = signer.CreateSignedRequest(ctx.ProtocolMessage);

            // then the library adds the client assertion (private_key_jwt)
            if (originalPush is not null)
                await originalPush(ctx);
        };
    });
```

`CreateSignedRequest` and `ParIsUsed` stand for your own code. The library does not create JAR request objects, so signing is your responsibility.

Order the registrations so your `PostConfigure` runs after `AddOpenIdConnectAccessTokenManagement`. That way the handlers you capture are the library's.

## Verifying and related notes

- Check that the authorize or PAR request contains `dpop_jkt`. With JAR it must be inside the signed `request` JWT. On the token endpoint, expect a `DPoP` header on the code exchange and on refreshes.
- `ClientAssertionFactory` creates a fresh assertion (unique `jti`) per attempt, so PAR or token retries don't reuse one.
- Keep the DPoP JWK stable (Key Vault or secrets, for example `DPoP:JsonWebKey`). A key regenerated on every restart invalidates previously issued DPoP-bound tokens and causes 401s.
- DPoP stores the proof key per user session in the OIDC `state` and the auth cookie, which increases their size. If that becomes a problem, configure `StateDataFormat` on the OIDC options and `SessionStore` on the cookie options.
