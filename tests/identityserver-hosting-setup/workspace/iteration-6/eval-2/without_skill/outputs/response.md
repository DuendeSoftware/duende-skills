# Middleware order

**What's wrong:** `UseIdentityServer` is placed before `UseRouting`. IdentityServer's endpoints and its authentication handling should run after routing so endpoint metadata is available, and `UseIdentityServer` itself calls `UseAuthentication`, so the separate call is redundant (harmless but unnecessary).

**Correct order:**
```csharp
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // also performs authentication
app.UseAuthorization();
app.MapRazorPages();
```

Key points: routing first, then IdentityServer (replacing `UseAuthentication`), then authorization, then endpoint mapping. If you keep `UseAuthentication` explicitly, put it before `UseIdentityServer` or just drop it.
