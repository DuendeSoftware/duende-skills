# Token storage with server-side sessions, and the in-memory store

## Cookie vs. server

The whole point of **server-side sessions** is that the cookie stops carrying the payload. With server-side sessions the browser cookie holds **only a session identifier** — a random key that maps to data kept on the server. The claims and tokens are no longer serialized into the cookie.

## Where the tokens are

**All of the OAuth/OIDC tokens are stored server-side, in the session store** — the access token, the ID token, and the **refresh token**. None of them are in the cookie. That's a security benefit: the refresh token, which is the sensitive long-lived credential, never sits in the browser; the browser only ever holds the opaque session id.

## Is the in-memory store OK for 3 nodes?

**No.** The in-memory session store has two problems that make it unsuitable for a multi-node cluster:

1. **It isn't durable.** Sessions are held in process memory, so a restart or redeploy wipes them and everyone is logged out.
2. **It isn't shared between nodes.** Each instance has its own memory. If the load balancer creates a session on node 1 and later routes the same user to node 2, node 2 doesn't have that session id and treats the user as unauthenticated — so users get "randomly" logged out as they bounce between nodes.

## What to use instead

For a 3-node deployment you need a **shared, persistent session store** that all instances read from and write to — typically backed by a **database (SQL) or Redis**. That way any node can resolve any session, and sessions survive restarts.

A couple of related things to get right at the same time:

- Configure **ASP.NET Core Data Protection** with a shared key ring across all nodes, otherwise the session cookie encrypted by one node can't be read by another (another common cause of random logouts).
- Optionally enable sticky sessions on the load balancer, but that's a mitigation, not a substitute for a shared store.

**Summary:** cookie = session id only; all tokens (including the refresh token) live in the server-side store; the in-memory store is neither durable nor shared, so for 3 nodes use a shared persistent store (SQL/Redis) plus shared Data Protection keys.
