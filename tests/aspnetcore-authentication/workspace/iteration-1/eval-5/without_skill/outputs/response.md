# Adding Custom Parameters and Error Handling to OIDC

Here's how to customize the OIDC authentication flow:

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

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");
app.MapGet("/auth-error", () => "Authentication failed");

app.Run();
```

## Explanation

- **OnRedirectToIdentityProvider**: This event fires before the user is redirected to the identity provider. You can modify the protocol message to add custom parameters like `acr_values` and `login_hint`.
- **OnRemoteFailure**: This event fires when authentication fails. By calling `HandleResponse()` and redirecting, you prevent the default error behavior and show a custom page instead.
