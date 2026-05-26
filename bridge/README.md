# RR Bridge

Tiny local bridge API for the iOS app.

## Run

```bash
node server.js
```

Then test:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/player
curl http://localhost:3000/account-xp/mock-puuid
curl http://localhost:3000/parties/mock-party-id/queues
```

On your iPhone, use your PC's LAN IP instead of `localhost`:

```text
http://YOUR_PC_IP:3000/player
```

## Optional Local Secret

Set a simple bridge key before starting the server:

```bash
RR_BRIDGE_KEY=change-me node server.js
```

Then send this header from clients:

```text
X-RR-Bridge-Key: change-me
```

## Route Mapping

The private endpoint:

```text
https://pd.{shard}.a.pvp.net/account-xp/v1/players/{puuid}
```

maps to this local bridge route:

```text
GET /account-xp/:puuid
```

The private endpoint:

```text
https://glz-{region}-1.{shard}.a.pvp.net/parties/v1/parties/{party_id}/queues
```

maps to this local bridge route:

```text
GET /parties/:partyID/queues
```

These handlers return mock data right now. Keep the iOS app talking to the
bridge routes so you can change the bridge internals without changing Swift UI.
