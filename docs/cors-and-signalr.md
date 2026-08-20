# CORS and SignalR

## Why this needed changing

The API used to allow any origin:

```csharp
policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
```

That was fine while only native clients existed — they send no `Origin`
header, so CORS never applied to them — and it works for the Flutter web build
because auth is a Bearer token rather than a cookie.

It does **not** work for SignalR. Browser SignalR clients send credentials on
the `/negotiate` request, and the browser then refuses any response that
combines `Access-Control-Allow-Credentials: true` with
`Access-Control-Allow-Origin: *`. ASP.NET Core enforces the same rule from the
other side: combining `AllowAnyOrigin()` with `AllowCredentials()` throws at
runtime rather than silently misbehaving. Allowed origins therefore have to be
listed explicitly.

## How it works now

`Cors:AllowedOrigins` drives the policy:

- **Configured** — those origins are allowed, with credentials. This is what
  SignalR needs.
- **Not configured** — falls back to the old any-origin-without-credentials
  behaviour and logs a warning at startup. This is deliberate: a missing
  setting shouldn't take the API down, and the fallback is exactly the
  behaviour that shipped before. Browser SignalR will fail until it's set.

Native clients are unaffected either way.

## Setting it

**Production (Cloud Run).** `deploy.yml` reads two repository *variables*
(Settings → Secrets and variables → Actions → **Variables**, not Secrets —
these are public URLs):

| Variable | Example |
| --- | --- |
| `WEB_ORIGIN` | `https://forgefrom.netlify.app` |
| `WEB_ORIGIN_ALT` | `https://app.forgeform.com` (optional) |

They become `Cors__AllowedOrigins__0` and `__1`. One indexed key each, because
`gcloud run deploy --set-env-vars` splits on commas — a comma-separated list
would be parsed as separate variables.

**Local development.** With no configuration, `http://localhost:5000` and
`http://127.0.0.1:5000` are allowed automatically. `flutter run -d chrome`
picks a random port unless you pass `--web-port=5000`, so either pass it or add
the port it prints.

To override locally, use user-secrets or `appsettings.Development.json`:

```json
{ "Cors": { "AllowedOrigins": [ "http://localhost:5000" ] } }
```

## Two things that will waste your afternoon

**An origin is scheme + host + port, with no path and no trailing slash.**
`WithOrigins` compares the serialised origin exactly, so
`https://app.example.com/` never matches a real request. The API trims trailing
slashes defensively, but don't rely on that elsewhere.

**Dev defaults are set in `Program.cs`, not `appsettings.json`, on purpose.**
Configuration providers override arrays *per index*. A committed two-entry list
plus a one-entry environment override leaves entry `1` — a localhost origin —
trusted in production. Keeping defaults in code avoids that merge entirely.

## What CORS does not cover

CORS governs the HTTP `/negotiate` request. It does **not** govern the
WebSocket upgrade itself — browsers don't apply CORS to WebSockets, and
ASP.NET Core's WebSocket middleware allows every origin unless
`WebSocketOptions.AllowedOrigins` is set.

That's acceptable here because the hub requires a valid JWT
(`RequireAuthorization()`), passed as `?access_token=` rather than a cookie. A
hostile page has no way to obtain that token, so it cannot open an
authenticated socket — there are no ambient credentials for the browser to
attach. If cookie auth is ever introduced, this stops being true and
`WebSocketOptions.AllowedOrigins` becomes necessary.
