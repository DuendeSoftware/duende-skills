# Fixing Transport Security Behind AWS ALB

## Problem

When IdentityServer is behind a reverse proxy that terminates TLS, the inner request arrives as HTTP. This causes the discovery document to show an `http://` issuer.

## Fix ForwardedHeaders

You need to configure the forwarded headers middleware so ASP.NET Core knows the original request was HTTPS:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;
});
```

Then add it to the middleware pipeline:

```csharp
app.UseForwardedHeaders();
```

## Add HSTS

```csharp
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});
```

## Add HTTPS Redirection

```csharp
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status301MovedPermanently;
    options.HttpsPort = 443;
});
```

## Middleware Order

```csharp
app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseHsts();
app.UseIdentityServer();
```

This should fix the discovery document issue by ensuring IdentityServer sees the correct HTTPS scheme.
