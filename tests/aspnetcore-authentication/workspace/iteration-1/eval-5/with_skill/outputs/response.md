# Custom OIDC Parameters and Error Handling

Here's how to add custom parameters to the authorize request and handle authentication failures:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.SaveTokens = true;

    options.Events = new OpenIdConnectEvents
    {
        // Add custom parameters to the authorize request
        OnRedirectToIdentityProvider = context =>
        {
            // Add acr_values for tenant selection
            context.ProtocolMessage.AcrValues = "tenant:myorg";

            // Add login_hint with the user's email
            context.ProtocolMessage.LoginHint = "user@example.com";

            return Task.CompletedTask;
        },

        // Handle authentication failures with a custom error page
        OnRemoteFailure = context =>
        {
            context.HandleResponse();
            context.Response.Redirect("/auth-error?message=" +
                Uri.EscapeDataString(context.Failure?.Message ?? "Authentication failed"));
            return Task.CompletedTask;
        }
    };
});
```

## How It Works

- **`OnRedirectToIdentityProvider`** fires just before the browser is redirected to IdentityServer. You can modify `context.ProtocolMessage` to add custom parameters like `acr_values` and `login_hint`.
- **`OnRemoteFailure`** fires when the external authentication process fails (e.g., user cancels, token validation fails). `context.HandleResponse()` prevents the default error behavior, and you redirect to your custom error page.
