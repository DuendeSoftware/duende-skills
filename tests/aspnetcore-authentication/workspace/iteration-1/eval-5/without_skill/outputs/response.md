# Adding Custom OIDC Parameters

You can customize the OIDC authorize request using events:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;

    options.Events = new OpenIdConnectEvents
    {
        OnRedirectToIdentityProvider = context =>
        {
            context.ProtocolMessage.SetParameter("acr_values", "tenant:myorg");
            context.ProtocolMessage.SetParameter("login_hint", "user@example.com");
            return Task.CompletedTask;
        },
        OnRemoteFailure = context =>
        {
            context.HandleResponse();
            context.Response.Redirect("/auth-error");
            return Task.CompletedTask;
        }
    };
});
```

The `OnRedirectToIdentityProvider` event lets you modify the protocol message before the redirect. `OnRemoteFailure` handles failures by redirecting to a custom error page.
