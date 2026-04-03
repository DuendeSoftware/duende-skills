# Reference Token Introspection

For opaque tokens, you need OAuth 2.0 token introspection. The API calls the authorization server's introspection endpoint to validate the token.

## Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", options =>
    {
        options.Authority = "https://auth.mycompany.com";
        options.ClientId = "invoicing";
        options.ClientSecret = "invoicing_secret";
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.Run();
```

You'll need an OAuth2 introspection NuGet package. The introspection handler calls the token introspection endpoint at the authority URL to validate opaque tokens.
