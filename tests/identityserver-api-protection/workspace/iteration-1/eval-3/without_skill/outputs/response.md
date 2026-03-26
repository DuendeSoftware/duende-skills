# Supporting Both JWT and Reference Tokens

To handle both token types in a single API, you can configure multiple authentication schemes and use a policy selector.

## Configure Both Handlers

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        options.ForwardDefaultSelector = context =>
        {
            string token = context.Request.Headers["Authorization"]
                .FirstOrDefault()?.Replace("Bearer ", "") ?? "";
            // If token contains dots, it's a JWT; otherwise it's a reference token
            return token.Contains('.') ? null : "Introspection";
        };
    })
    .AddOAuth2Introspection("Introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "api1";
        options.ClientSecret = "api1_secret";
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## How It Works

The `ForwardDefaultSelector` inspects the token format. JWTs always contain dots (header.payload.signature), while reference tokens are opaque strings without dots. Based on this check, the request is routed to the appropriate handler.
