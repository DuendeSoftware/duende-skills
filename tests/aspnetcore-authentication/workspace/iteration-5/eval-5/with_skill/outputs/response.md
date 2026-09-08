Use the OIDC handler's `Events` (`OpenIdConnectEvents`). `OnRedirectToIdentityProvider` lets you add custom parameters to the authorize request, and `OnRemoteFailure` lets you take over error handling and redirect wherever you want.

```csharp
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;

    options.Events = new OpenIdConnectEvents
    {
        // Add custom parameters to the /authorize request
        OnRedirectToIdentityProvider = context =>
        {
            // acr_values — request a specific tenant/authentication context
            context.ProtocolMessage.AcrValues = "tenant:myorg";

            // login_hint — prefill the user's email on the login screen.
            // Pull it from wherever you have it (existing principal, query string, etc.)
            var email =
                context.HttpContext.User.FindFirst("email")?.Value
                ?? context.HttpContext.Request.Query["email"].ToString();

            if (!string.IsNullOrEmpty(email))
            {
                context.ProtocolMessage.LoginHint = email;
                // equivalently: context.ProtocolMessage.SetParameter("login_hint", email);
            }

            return Task.CompletedTask;
        },

        // Send failed logins to your own error page instead of the default handler
        OnRemoteFailure = context =>
        {
            // Stop the default failure handling (which throws / shows the generic error)
            context.HandleResponse();
            context.Response.Redirect("/auth-error");
            return Task.CompletedTask;
        }
    };
});
```

### What each piece does

- **`OnRedirectToIdentityProvider`** fires right before the browser is redirected to IdentityServer's `/connect/authorize`. `context.ProtocolMessage` is the outgoing request, so anything you set there is added as a query parameter.
  - `ProtocolMessage.AcrValues = "tenant:myorg"` adds `acr_values=tenant:myorg`.
  - `ProtocolMessage.LoginHint = email` adds `login_hint=<email>`. For arbitrary custom parameters, use `context.ProtocolMessage.SetParameter("name", "value")`.
- **`OnRemoteFailure`** fires when the callback fails (user cancels, `error=` returned, nonce/state mismatch, etc.).
  - `context.HandleResponse()` tells the middleware you've fully handled the response — it won't run its default error logic or re-throw.
  - `context.Response.Redirect("/auth-error")` sends the user to your custom page. You can append `context.Failure?.Message` as a query string if you want to surface the reason.

> If you don't call `HandleResponse()`, the framework continues its own error handling and your redirect won't take effect.
