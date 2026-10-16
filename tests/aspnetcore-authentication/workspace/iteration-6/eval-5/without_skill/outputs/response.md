```csharp
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(o =>
{
    o.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    o.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie()
.AddOpenIdConnect(o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web.app";
    o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.UsePkce = true;
    o.SaveTokens = true;
    o.Scope.Add("profile");

    o.Events = new OpenIdConnectEvents
    {
        OnRedirectToIdentityProvider = ctx =>
        {
            ctx.ProtocolMessage.AcrValues = "tenant:myorg";

            // email may be passed via AuthenticationProperties.Items
            if (ctx.Properties.Items.TryGetValue("login_hint", out var hint) && hint != null)
                ctx.ProtocolMessage.LoginHint = hint;
            return Task.CompletedTask;
        },
        OnRemoteFailure = ctx =>
        {
            ctx.Response.Redirect("/auth-error?message=" + Uri.EscapeDataString(ctx.Failure?.Message ?? "error"));
            ctx.HandleResponse();
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();
var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/login", (string? email) =>
{
    var props = new AuthenticationProperties { RedirectUri = "/" };
    if (!string.IsNullOrEmpty(email)) props.Items["login_hint"] = email;
    return Results.Challenge(props, new[] { OpenIdConnectDefaults.AuthenticationScheme });
});
app.MapGet("/auth-error", () => "Authentication failed");
app.MapGet("/", () => "Hello World!");
app.Run();
```

`OnRedirectToIdentityProvider` modifies the authorize request; `OnRemoteFailure` handles callback failures, and `HandleResponse()` stops the default handling.
