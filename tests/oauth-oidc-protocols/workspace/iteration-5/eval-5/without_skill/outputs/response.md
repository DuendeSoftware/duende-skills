# Getting User Info in Your Client

The root of the problem is that your client was reading the **access token** to get the user's name and email. That's not what an access token is for, which is why the server upgrade broke it.

## Why it broke

An access token is meant to be sent to an API to authorize requests. Its format is an implementation detail of the server and the API — it can be a JWT or an opaque "reference" token. When your server switched from JWT to reference tokens, the access token became an opaque string with no readable claims inside, so any code trying to decode it as a JWT stopped working.

As a general rule, a **client should not try to parse or depend on the contents of the access token**. Just treat it as an opaque value that you attach to API calls (`Authorization: Bearer <token>`). Only the API that receives the token needs to validate and read it.

## Where to get user info instead

In OpenID Connect there are two proper places for user identity information:

### The ID token

The **ID token** is specifically issued to the client to represent the authenticated user. It's a JWT and contains identity claims like `sub`, `name`, and `email` (depending on the scopes you request — `openid`, `profile`, `email`). This is the token your UI should use for displaying the user's name and email.

If you're using an OIDC library/middleware, it validates the ID token for you and exposes the claims through the user/principal object, so you read them from there rather than decoding a token manually.

### The userinfo endpoint

Alternatively, OpenID Connect defines a **userinfo endpoint**. You call it with the access token and it returns the user's claims as JSON. This is useful if you want fresh claims or claims that aren't included in the ID token.

```
GET /connect/userinfo
Authorization: Bearer <access_token>
```

## The key distinction

- **ID token** → tells the *client* who the user is (authentication). Consumed by your app.
- **Access token** → lets your app call an *API* (authorization). Consumed by the API, opaque to your app.

So the fix is: request the `openid profile email` scopes, get `name`/`email` from the ID token (via your auth middleware's user principal) or from the userinfo endpoint, and stop reading the access token in your client.
