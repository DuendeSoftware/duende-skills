# gRPC Client with User Access Token

To call a downstream gRPC service with the current user's access token, you can use Duende.AccessTokenManagement with gRPC client factory.

## Program.cs

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
        options.Scope.Add("grpc_api");
        options.SaveTokens = true;
    });

// Register token management
builder.Services.AddAccessTokenManagement();

// Register gRPC client with user token
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddCallCredentials(async (context, metadata, serviceProvider) =>
{
    var httpContextAccessor = serviceProvider.GetRequiredService<IHttpContextAccessor>();
    var token = await httpContextAccessor.HttpContext!.GetTokenAsync("access_token");
    if (!string.IsNullOrEmpty(token))
    {
        metadata.Add("Authorization", $"Bearer {token}");
    }
});

builder.Services.AddHttpContextAccessor();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/greet", async (Greeter.GreeterClient grpcClient) =>
{
    var reply = await grpcClient.SayHelloAsync(new HelloRequest { Name = "World" });
    return Results.Ok(reply.Message);
}).RequireAuthorization();

app.Run();
```

## Explanation

- `AddGrpcClient<T>()` registers the typed gRPC client with the downstream endpoint.
- `AddCallCredentials` provides a delegate that reads the user's access token from the HttpContext and adds it to the gRPC metadata.
- The token is obtained from the authentication session via `GetTokenAsync("access_token")`.
