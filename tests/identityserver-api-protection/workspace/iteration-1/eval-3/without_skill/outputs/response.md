# Supporting Both JWT and Reference Tokens

To handle both JWT and reference tokens, you need to configure two authentication handlers and route between them based on the token format.

## Configure Authentication

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
    })
    .AddOAuth2Introspection("Introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "api1";
        options.ClientSecret = "api1_secret";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Routing Between Handlers

You'll need to configure a `ForwardDefaultSelector` on the JWT bearer handler to route reference tokens to the introspection handler. JWTs contain dots (header.payload.signature format) while reference tokens are opaque strings without dots.

You can add a custom selector:

```csharp
.AddJwtBearer("Bearer", options =>
{
    options.Authority = "https://identity.example.com";
    options.Audience = "api1";

    options.ForwardDefaultSelector = context =>
    {
        string authorization = context.Request.Headers.Authorization.FirstOrDefault();
        if (!string.IsNullOrEmpty(authorization) && authorization.StartsWith("Bearer "))
        {
            var token = authorization.Substring("Bearer ".Length).Trim();
            if (!token.Contains('.'))
            {
                return "Introspection";
            }
        }
        return null;
    };
});
```

This checks if the token contains a dot — if it does, it's a JWT and handled by the JWT bearer handler. If not, it's forwarded to the introspection handler.
