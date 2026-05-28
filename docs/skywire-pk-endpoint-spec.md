# Spec: `/api/pk` route on the hypervisor

**For the agent working in `0pcom/skywire`.** skybian's first-boot autoconfig
(`skymanager.sh`) needs to discover a hypervisor's pubkey by querying the
hypervisor's own UI port. This is the contract.

## What to add

A new HTTP route, `GET /api/pk`, on the hypervisor's chi router. It must be
**unauthenticated in the user-account sense** — visors that don't have an account
on this hypervisor still need to learn its pubkey to peer with it. The route does
require a soft `SW-Public` header check (see below); that's a "looks like another
visor" gate, not real auth.

### Soft gate: `SW-Public` header

The handler reads the `SW-Public` request header (the same one
`pkg/httpauthclient` already sets on every visor→service HTTP call). The header
value must be a 66-hex-character `cipher.PubKey`. No nonce, no signature, no
account lookup.

- Missing header → `401 Unauthorized`.
- Malformed header value → `400 Bad Request`.
- Well-formed → `200 OK` with the pubkey body.

The skybian-side consumer (`skymanager.sh`) must set this header naming the
requesting visor's own PK.

### Operator opt-in: `enable_pk_endpoint`

`HypervisorConfig.EnablePKEndpoint` (`"enable_pk_endpoint"` in JSON, default
`false`) controls whether the route is registered at all. **Off by default** —
vanilla hypervisor configs do NOT expose the route, and chi returns 404 for
`GET /api/pk` (indistinguishable from a hypervisor that doesn't implement it).
The skybian / Arch-ARM image builds set it to `true` at image-build time via:

```
skywire cli config gen -in --pk-endpoint > /opt/skywire/skywire.json
```

(or via the `ENABLEPKENDPOINT=true` env knob the gen command honors).

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

- `pkg/visor/visorconfig/hypervisorconfig.go` — `EnablePKEndpoint bool`
  field with `json:"enable_pk_endpoint"` (no omitempty — the field is
  always serialized).

- `pkg/visor/hypervisor.go` — gated route registration inside the existing
  unauth block:

  ```go
  r.Route("/api", func(r chi.Router) {
      r.Use(middleware.Timeout(httpTimeout))
      r.Get("/ping", hv.getPong())
      r.Get("/csrf", hv.getCsrf())
      r.Get("/user-exists", hv.users.UserExists())
      if hv.c.EnablePKEndpoint {
          r.Get("/pk", hv.getPK())
      }
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

- `pkg/visor/hypervisor_handlers_misc.go` — `getPK()` with the SW-Public
  gate:

  ```go
  func (hv *Hypervisor) getPK() http.HandlerFunc {
      return func(w http.ResponseWriter, r *http.Request) {
          caller := strings.TrimSpace(r.Header.Get("SW-Public"))
          if caller == "" {
              httputil.WriteJSON(w, r, http.StatusUnauthorized, struct {
                  Error string `json:"error"`
              }{Error: "SW-Public header required"})
              return
          }
          var callerPK cipher.PubKey
          if err := callerPK.Set(caller); err != nil {
              httputil.WriteJSON(w, r, http.StatusBadRequest, struct {
                  Error string `json:"error"`
              }{Error: "SW-Public header is not a valid public key"})
              return
          }
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

Bring up a hypervisor visor, then from any LAN host (replace `<visor-pk>` with
the requesting visor's own pubkey):

```
curl -fsS -H "SW-Public: <visor-pk>" http://<hv-ip>:8000/api/pk
# {"public_key":"030e...66hex"}
```

The pubkey returned must match what `skywire-cli visor pk` reports on the
hypervisor itself.

### Negative tests

- `GET /api/pk` without `SW-Public` → 401.
- `GET /api/pk` with malformed `SW-Public` → 400.
- `GET /api/pk` with valid `SW-Public` → 200 regardless of `EnableAuth`.
- Hypervisor with `"enable_pk_endpoint": false` (the default) → 404 for any
  `GET /api/pk` regardless of header state (indistinguishable from a
  hypervisor that doesn't implement the route).
- Pubkey output is exactly 66 hex chars when interpreted as a string.

### What consumes this

- `skybian/script/skymanager.sh` (this repo). It must set the `SW-Public`
  header naming the requesting visor's PK before issuing the curl. The
  visor's own pubkey is already known to the autoconfig script at this
  point (it ran `skywire-cli visor pk` immediately before). The script
  greps for the first 66-hex run in the response — the JSON envelope is
  fine, no extra parser dependency.

### Companion change on the consumer side

`skymanager.sh` must:

1. Ensure the visor's keypair exists before issuing `GET /api/pk`.
   `cipher.PubKey.Set()` goes through `secp256k1.VerifyPubkey` (actual curve
   membership check) — synthetic strings of the form `02|03 + 64 hex` do
   **not** pass it, so we cannot fake a PK for the discovery probe. Concrete
   path used in skybian: run `skywire-cli config gen -o /opt/skywire/skywire.json`
   once at the top of `skymanager`, grep the PK out of the resulting JSON,
   and pass it via `-H "SW-Public: <pk>"`. `skywire-autoconfig` later
   regenerates with `-r`, which retains the keypair (so the PK we
   advertised in the probe stays stable).
2. Set `ENABLEPKENDPOINT=true` in the environment seen by every
   `skywire-cli config gen` call. The `--pk-endpoint` flag's default is
   `scriptExecBool("${ENABLEPKENDPOINT:-false}")` and `config gen -r`
   resets `EnablePKEndpoint` from the flag (not from the prior config) on
   every regen, so this **must** live in the env — `/etc/profile.d/skyenv.sh`
   is the right place since `skywire-autoconfig` sources it on every run.

### Out of scope

- No CORS headers needed; the consumer is `curl` from a script.
- No rate limiting needed.
- No CSRF (it's a GET).
- Do **not** expose `/api/about` unauthenticated; this spec is just `/api/pk`.
