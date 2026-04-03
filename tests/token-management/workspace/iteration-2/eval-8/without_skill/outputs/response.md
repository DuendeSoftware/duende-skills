# gRPC Client with User Access Token

Here's how to set up a gRPC client that automatically attaches the user's access token.

## `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure authentication
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "OpenIdConnect";
})
.AddCookie("Cookies")
.AddOpenIdConnect("OpenIdConnect", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "webapp";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;
    options.Scope.Add("openid");
    options.Scope.Add("grpc.api");
});

// Register gRPC client
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/greet", async (Greeter.GreeterClient grpcClient, HttpContext httpContext, CancellationToken ct) =>
{
    // Get the access token and set it manually
    var token = await httpContext.GetTokenAsync("access_token");
    
    var headers = new Grpc.Core.Metadata
    {
        { "Authorization", $"Bearer {token}" }
    };
    
    var reply = await grpcClient.SayHelloAsync(
        new HelloRequest { Name = "World" },
        headers: headers,
        cancellationToken: ct);
    return Results.Ok(reply.Message);
}).RequireAuthorization();

app.Run();
```

## Notes

- The gRPC client is registered using `AddGrpcClient<T>()`.
- You need to manually retrieve the access token from `HttpContext` and pass it in the gRPC metadata headers.
- Make sure `SaveTokens = true` is set on the OIDC handler so tokens are available.
- For a cleaner approach, you could create a custom `DelegatingHandler` that attaches the token automatically.
