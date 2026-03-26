# gRPC Client with User Access Token in ASP.NET Core

To call a downstream gRPC endpoint using the current user's access token, you can integrate gRPC client factory with token management.

## Setup

First, install the required packages:

```bash
dotnet add package Grpc.Net.ClientFactory
dotnet add package Duende.AccessTokenManagement.OpenIdConnect
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Authentication
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
    options.SaveTokens = true;
    options.Scope.Add("openid");
    options.Scope.Add("grpc.api");
    options.Scope.Add("offline_access");
});

// Token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register gRPC client with token handler
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddUserAccessTokenHandler();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/greet", async (Greeter.GreeterClient client) =>
{
    var reply = await client.SayHelloAsync(new HelloRequest { Name = "World" });
    return Results.Ok(reply.Message);
}).RequireAuthorization();

app.Run();
```

## Explanation

The `AddGrpcClient<T>()` method registers a typed gRPC client. By chaining `.AddUserAccessTokenHandler()`, a delegating handler is added that automatically retrieves and attaches the user's access token to outgoing gRPC calls. The `AddOpenIdConnectAccessTokenManagement()` call is required as a prerequisite to enable the user token management infrastructure.

gRPC in .NET uses `HttpClient` internally, so the same token handler pattern works for both REST and gRPC clients.
