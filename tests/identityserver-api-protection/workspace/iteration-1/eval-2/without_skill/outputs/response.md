# Setting Up Reference Token Validation

For opaque/reference tokens, you need to use token introspection. Here's how:

## Install Package

```bash
dotnet add package IdentityModel.AspNetCore.OAuth2Introspection
```

## Configure Introspection

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddOAuth2Introspection("Bearer", options =>
    {
        options.Authority = "https://auth.mycompany.com";
        options.ClientId = "invoicing";
        options.ClientSecret = "invoicing_secret";
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## How It Works

The introspection handler sends the opaque token to the authorization server's introspection endpoint. The server validates the token and returns whether it's active along with associated claims.

The `ClientId` and `ClientSecret` are used to authenticate the API to the introspection endpoint.
