# Spec: `/api/pk` route on the hypervisor

**For the agent working in `0pcom/skywire`.** skybian's first-boot autoconfig
(`skymanager.sh`) needs to discover a hypervisor's pubkey by querying the
hypervisor's own UI port. This is the contract.

## What to add

A new HTTP route, `GET /api/pk`, on the hypervisor's chi router. It must be
**unauthenticated** — visors that don't have an account on this hypervisor still
need to learn its pubkey to peer with it.

### Response shape (JSON envelope, chosen for symmetry with the other `/api/` routes)

```
HTTP/1.1 200 OK
Content-Type: application/json

{"public_key":"030e...66hex"}
```

Field name is `public_key` (snake_case to match the way `cipher.PubKey` typically
appears in skywire's JSON output elsewhere). The value is the 66-character hex
encoding of the hypervisor's own pubkey.

### Files to touch

- `pkg/visor/hypervisor.go` — add the route registration inside the existing
  unauth block. Current state (line ~611):

  ```go
  r.Route("/api", func(r chi.Router) {
      r.Use(middleware.Timeout(httpTimeout))
      r.Get("/ping", hv.getPong())
      r.Get("/csrf", hv.getCsrf())
      r.Get("/user-exists", hv.users.UserExists())
      // <-- add r.Get("/pk", hv.getPK()) here, before the EnableAuth group
      if hv.c.EnableAuth {
          ...
      }
      r.Group(func(r chi.Router) {
          if hv.c.EnableAuth {
              r.Use(hv.users.Authorize)
          }
          ...
      })
  })
  ```

- `pkg/visor/hypervisor_handlers_misc.go` — add `getPK()` modeled on `getAbout()`:

  ```go
  func (hv *Hypervisor) getPK() http.HandlerFunc {
      return func(w http.ResponseWriter, r *http.Request) {
          httputil.WriteJSON(w, r, http.StatusOK, struct {
              PublicKey cipher.PubKey `json:"public_key"`
          }{
              PublicKey: hv.c.PK,
          })
      }
  }
  ```

  (`hv.c.PK` is already used by `getAbout` for the same value.)

### Why not just unlock `/api/about`?

`/api/about` is already authenticated and leaks build info, dmsg session count,
etc. The discovery protocol only needs the pubkey; a dedicated route is the
minimum surface to expose unauthenticated.

### Test plan

Bring up a hypervisor visor, then from any LAN host:

```
curl -fsS http://<hv-ip>:8000/api/pk
# {"public_key":"030e...66hex"}
```

The pubkey returned must match what `skywire-cli visor pk` reports on the
hypervisor itself.

### Negative tests

- `GET /api/pk` from an unauthenticated context returns 200 (the whole point).
- Verify the route is unaffected by `EnableAuth=true`.
- Pubkey output is exactly 66 hex chars when interpreted as a string.

### What consumes this

- `skybian/script/skymanager.sh` (this repo). It greps for the first 66-hex run
  in the response — JSON wrapper or bare hex both work. So the JSON envelope
  above is fine, no extra parser dependency on the visor side.

### Out of scope

- No CORS headers needed; the consumer is `curl` from a script.
- No rate limiting needed.
- No CSRF (it's a GET).
- Do **not** expose `/api/about` unauthenticated; this spec is just `/api/pk`.
