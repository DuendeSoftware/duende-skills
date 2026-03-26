# Fixing the Middleware Pipeline

The ordering is wrong. Here's the correct order:

```csharp
var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseIdentityServer();
app.UseAuthorization();
```

`UseRouting()` needs to come first so the endpoints can be matched. `UseAuthentication()` should come before `UseIdentityServer()`, and `UseAuthorization()` comes last.
