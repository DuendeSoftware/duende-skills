# Handling Both JWT and Reference Tokens

You can set up multiple authentication schemes and use a policy selector to choose the right handler based on the token format.

```csharp
var builder = WebApplication.CreateBuilder(args);

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

// You could implement a custom policy scheme to route based on token format
builder.Services.AddAuthentication("smart")
    .AddPolicyScheme("smart", "JWT or Reference", options =>
    {
        options.ForwardDefaultSelector = context =>
        {
            var authHeader = context.Request.Headers["Authorization"].FirstOrDefault();
            if (authHeader?.StartsWith("Bearer ") == true)
            {
                var token = authHeader.Substring("Bearer ".Length);
                if (token.Contains('.'))
                    return "Bearer";
            }
            return "Introspection";
        };
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

This checks whether the token contains dots (JWTs have dots separating header.payload.signature) and routes accordingly.
