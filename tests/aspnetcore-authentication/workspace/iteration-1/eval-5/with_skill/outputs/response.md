# Custom OIDC Authorize Parameters and Error Handling

Here's how to add custom parameters to the OIDC authorize request and handle authentication failures with a custom error page:

```csharp
var builder = WebApplication.CreateBuilder(args);

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

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");

    // Configure OIDC handler events for customization
    options.Events = new OpenIdConnectEvents
    {
        // Customize the authorize request
        OnRedirectToIdentityProvider = context =>
        {
            // Add acr_values to request specific authentication methods or tenant
            context.ProtocolMessage.AcrValues = "tenant:myorg";

            // Add login_hint to pre-fill the username field
            context.ProtocolMessage.LoginHint = "user@example.com";

            return Task.CompletedTask;
        },

        // Handle authentication failures (remote failures from IdentityServer)
        OnRemoteFailure = context =>
        {
            // Prevent the default exception handling
            context.HandleResponse();

            // Redirect to custom error page
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
app.MapGet("/auth-error", () => Results.Content("Authentication failed. Please try again.", "text/html"));

app.Run();
```

## How Events Work

The OIDC handler fires events at specific points during the authentication flow:

| Event | When It Fires | Common Use Cases |
|-------|--------------|------------------|
| `OnRedirectToIdentityProvider` | Before redirecting to the authorize endpoint | Add `acr_values`, `login_hint`, custom parameters |
| `OnTokenValidated` | After the ID token is validated | Transform claims, load additional user data |
| `OnRemoteFailure` | When authentication fails | Custom error pages, logging |
| `OnSignedOutCallbackRedirect` | After sign-out callback | Custom post-logout behavior |

### Key Points

- **`context.ProtocolMessage.AcrValues`**: Passes authentication context class reference values. IdentityServer uses these for things like tenant selection or step-up authentication.
- **`context.ProtocolMessage.LoginHint`**: Pre-fills the login form with the user's email or username.
- **`context.HandleResponse()`**: Tells the middleware that you've handled the response yourself — without this, the default error handling would throw an exception.
