# Replacement for `IAuthorizationParametersMessageStore`

I'm not sure what v8 introduces. The v7 interface existed to stash large authorization parameters server-side, which was used for the `AuthorizationParametersMessageStore`/`returnUrl` flow, so the login `returnUrl` didn't carry everything.

In v8, as far as I know, this is handled by **pushed authorization requests (PAR)** and `IPushedAuthorizationRequestStore`, which is the standards-based way to avoid large request URLs. Alternatively, v8 may keep the parameters server-side in an internal store that you no longer implement.

What to do:
- If you only *consumed* the store, remove the usage. The login page gets what it needs from `IIdentityServerInteractionService.GetAuthorizationContextAsync(returnUrl)`.
- If you *implemented* a custom store, you probably need to move to whichever replacement the release notes name. Check Duende's v8 upgrade guide.
- For large requests, enable PAR (`options.Endpoints.EnablePushedAuthorizationEndpoint = true`) and have clients use it. Request objects (JAR) are another option.
