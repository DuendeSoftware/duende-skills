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
        // Customize the authorize request
        OnRedirectToIdentityProvider = context =>
        {
            context.ProtocolMessage.AcrValues = "tenant:myorg";

            // login_hint passed from the challenge via AuthenticationProperties
            if (context.Properties.Items.TryGetValue("login_hint", out var email)
                && !string.IsNullOrEmpty(email))
            {
                context.ProtocolMessage.LoginHint = email;
            }
            return Task.CompletedTask;
        },

        // Failed login -> custom page
        OnRemoteFailure = context =>
        {
            context.HandleResponse();
            context.Response.Redirect("/auth-error?message=" +
                Uri.EscapeDataString(context.Failure?.Message ?? "Unknown error"));
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();
var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/login", (string email) =>
{
    var props = new AuthenticationProperties { RedirectUri = "/" };
    props.Items["login_hint"] = email;
    return Results.Challenge(props, new[] { "oidc" });
});
app.MapGet("/auth-error", (string? message) => Results.Text($"Authentication failed: {message}"));
app.MapGet("/", () => "Hello World!");
app.Run();
```

- `OnRedirectToIdentityProvider` modifies the outgoing authorize request (`acr_values`, `login_hint`).
- `OnRemoteFailure` handles failures from the callback; `HandleResponse()` suppresses the default error handling before the redirect to `/auth-error`.
