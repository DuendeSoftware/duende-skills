# Adding Custom Parameters and Error Handling to OIDC

Here's the updated `Program.cs` with OIDC handler events configured for custom authorize parameters and error handling:

```csharp
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };

    // Configure OIDC handler events
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
            context.Response.Redirect("/auth-error");
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.MapGet("/auth-error", () => Results.Content(
    "<h1>Authentication Error</h1><p>Something went wrong during login.</p>",
    "text/html"));

app.Run();
```

## How the Events Work

### OnRedirectToIdentityProvider

This event fires just before the user is redirected to IdentityServer's authorize endpoint. You can modify the `ProtocolMessage` to add custom parameters:

- **`AcrValues = "tenant:myorg"`** — Sends `acr_values=tenant:myorg` to IdentityServer. This is commonly used for tenant selection in multi-tenant scenarios. IdentityServer can read this to customize the login experience.
- **`LoginHint = "user@example.com"`** — Sends `login_hint=user@example.com` to pre-fill the login form with the user's email address.

You can also use `context.ProtocolMessage.SetParameter("custom_param", "value")` for arbitrary custom parameters.

### OnRemoteFailure

This event fires when the OIDC authentication process fails (e.g., the user denies consent, the authorization code exchange fails, or the token validation fails).

- **`context.HandleResponse()`** — Tells the middleware that you're handling the response yourself, preventing the default error behavior.
- **`context.Response.Redirect("/auth-error")`** — Redirects to your custom error page instead of showing the default ASP.NET Core error.

Without `HandleResponse()`, the OIDC middleware would propagate the exception up the middleware pipeline.
