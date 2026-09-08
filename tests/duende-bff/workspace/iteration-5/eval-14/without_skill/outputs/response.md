# Making a BFF endpoint redirect instead of returning 401/403

## Why BFF returns 401/403 instead of redirecting

By design, BFF-marked API endpoints don't perform the classic "redirect the browser to the login page" behavior. When the user isn't authenticated (or isn't authorized), BFF turns what would normally be a `302` challenge redirect into a plain **`401`/`403` status** with no redirect. That's intentional for SPAs: a `fetch()` call can't follow a cross-document redirect to the IdP, so BFF gives the JavaScript a status code it can react to (typically by navigating to `/bff/login`). For an endpoint that's actually hit by a browser navigation, you may instead want the real OIDC challenge/redirect.

## Option 1: override the cookie authentication redirect events

The 401/403-instead-of-redirect behavior ultimately comes from how the challenge is handled. You can restore the redirect for interactive requests by customizing the cookie handler's events so a challenge on this path issues the normal redirect to the IdP:

```csharp
.AddCookie("cookie", options =>
{
    options.Events.OnRedirectToLogin = context =>
    {
        // Allow the real redirect for interactive endpoints
        if (context.Request.Path.StartsWithSegments("/api/interactive"))
        {
            context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        }
        // Otherwise keep the API-friendly 401
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        return Task.CompletedTask;
    };
});
```

The endpoint itself stays a normal authorized BFF endpoint:

```csharp
app.MapGet("/api/interactive", () => Results.Ok("data"))
    .RequireAuthorization()   // triggers the challenge when unauthenticated
    .AsBffApiEndpoint();
```

## Option 2: a dedicated interactive route

Alternatively, expose the interactive action on a route that is *not* marked as a BFF API endpoint, so the default ASP.NET Core authentication redirect applies and the user is sent through the OIDC flow normally.

## Recommendation

Check the Duende BFF v4 docs for a built-in per-endpoint switch to opt out of the API response handling — that's the cleanest approach if it exists. Otherwise the cookie-events override above gives you redirect behavior for the specific interactive path while keeping the API-friendly 401s everywhere else.
