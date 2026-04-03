# Custom Parameters and Error Handling for OIDC

You can customize the OIDC authentication flow using events. Here's how:

```csharp
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie()
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

## What This Does

- `OnRedirectToIdentityProvider` fires before the redirect to the identity provider. You can add custom parameters using `SetParameter`.
- `acr_values` tells the identity provider about tenant context.
- `login_hint` pre-fills the username field.
- `OnRemoteFailure` fires when authentication fails. `HandleResponse()` stops the default error handling and lets you redirect to a custom page.
