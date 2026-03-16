# Blazor Server Token Management

## The Problem

In Blazor Server, the `HttpContext` is only available during the initial HTTP request. Once the SignalR circuit is established, `HttpContext` becomes null. If your token management code relies on `HttpContext` (which is the default), token operations will fail after the circuit is set up, leading to 401 errors when tokens expire.

## Solution

You need to store tokens outside of the HTTP context so they can be accessed from the circuit. Here's how:

### Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    });

builder.Services.AddAccessTokenManagement();
builder.Services.AddHttpContextAccessor();

// Store tokens in a service that can be accessed from the circuit
builder.Services.AddScoped<TokenProvider>();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
```

### TokenProvider

```csharp
public class TokenProvider
{
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
}
```

### Capturing tokens during initial render

In your `App.razor` or `_Host.cshtml`, capture the tokens during the initial HTTP request:

```csharp
@inject TokenProvider TokenProvider
@inject IHttpContextAccessor HttpContextAccessor

@code {
    protected override async Task OnInitializedAsync()
    {
        var httpContext = HttpContextAccessor.HttpContext;
        if (httpContext != null)
        {
            TokenProvider.AccessToken = await httpContext.GetTokenAsync("access_token");
            TokenProvider.RefreshToken = await httpContext.GetTokenAsync("refresh_token");
        }
    }
}
```

Then use the `TokenProvider` in your components to access the token when making API calls.

## Explanation

- The `TokenProvider` is a scoped service that holds tokens for the duration of the circuit
- Tokens are captured during the initial HTTP request when `HttpContext` is still available
- Components inject `TokenProvider` instead of relying on `HttpContext`
- This avoids the null `HttpContext` problem in Blazor Server circuits
