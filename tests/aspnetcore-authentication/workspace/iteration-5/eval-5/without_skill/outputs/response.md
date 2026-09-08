You can hook into the OpenID Connect handler's events to both customize the outgoing authorize request and handle failures. The two events you need are `OnRedirectToIdentityProvider` (to add `acr_values` and `login_hint`) and `OnRemoteFailure` (to redirect to your own error page).

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

    options.Events = new OpenIdConnectEvents
    {
        OnRedirectToIdentityProvider = context =>
        {
            // acr_values
            context.ProtocolMessage.AcrValues = "tenant:myorg";

            // login_hint from the user's email
            var email = context.HttpContext.User?.FindFirst("email")?.Value;
            if (!string.IsNullOrEmpty(email))
            {
                context.ProtocolMessage.LoginHint = email;
            }

            return Task.CompletedTask;
        },

        OnRemoteFailure = context =>
        {
            context.HandleResponse();               // suppress default error handling
            context.Response.Redirect("/auth-error"); // go to your custom page
            return Task.CompletedTask;
        }
    };
});
```

### Notes

- **`OnRedirectToIdentityProvider`** runs just before the redirect to the identity provider. `context.ProtocolMessage` represents the authorize request, so:
  - `ProtocolMessage.AcrValues = "tenant:myorg"` adds the `acr_values` parameter.
  - `ProtocolMessage.LoginHint = email` adds the `login_hint` parameter. (You could also call `context.ProtocolMessage.SetParameter("login_hint", email)`.)
- **`OnRemoteFailure`** runs when the sign-in callback fails. Calling `context.HandleResponse()` prevents the framework from throwing/showing its default error, and `context.Response.Redirect("/auth-error")` sends the user to your page. Without `HandleResponse()`, your redirect would be overridden by the default behavior.

If you need the email before the user is known (e.g., from a form), read it from the query string or a stored value inside the event rather than from `context.HttpContext.User`.
