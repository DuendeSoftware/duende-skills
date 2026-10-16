# What gets cleaned up

## On logout
- The IdentityServer authentication cookie is removed and, with server-side sessions, the session row is deleted.
- Clients participating in the session are notified through front-channel and/or back-channel logout (if configured).
- Grants tied to that session (refresh tokens and reference access tokens issued for the session id) are revoked/removed, when the session is terminated. Consents are not removed.
- Self-contained JWT access tokens are not revocable; they stay valid until they expire.

## On expiry
When a server-side session merely expires (cleaned up by the background job):
- The session record is removed.
- If `ExpiredSessionsTriggerBackchannelLogout` is true, clients with a `BackChannelLogoutUri` are sent back-channel logout notifications so they can end their own sessions.
- Refresh tokens and reference tokens are not automatically revoked unless the client has `CoordinateLifetimeWithUserSession = true` (or global `CoordinateClientLifetimesWithUserSession`). Without that, they continue to live until their own lifetimes expire, which is why clients should be coordinated with the session if you want tokens to die with it.
- Clients that aren't notified keep their local session until their own cookie expires.
