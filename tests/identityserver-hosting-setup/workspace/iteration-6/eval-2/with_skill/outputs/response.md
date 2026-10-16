# Fixing the pipeline order

Current: `UseIdentityServer` → `UseRouting` → `UseAuthentication` → `UseAuthorization`

**Problems**
1. **IdentityServer is before routing.** `UseRouting` must come before `UseIdentityServer`.
2. **`UseAuthentication` is redundant.** `UseIdentityServer()` already includes `UseAuthentication()` internally. Having both is not harmful but unnecessary; remove it.
3. `UseAuthorization` must stay, after IdentityServer (the Duende UI needs it).

**Correct order**
```csharp
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication()
app.UseAuthorization();

app.MapDefaultControllerRoute(); // or MapRazorPages()
app.Run();
```

If behind a proxy, add `app.UseForwardedHeaders()` early, before `UseIdentityServer()`.
