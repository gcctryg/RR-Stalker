# RR Bridge

Tiny local bridge API for the iOS app.

## Run

```bash
node server.js
```

To proxy the real wallet endpoint, start the bridge with the shard and Riot
tokens from your PC session:

```bash
VALORANT_SHARD=na \
VALORANT_ACCESS_TOKEN=your-access-token \
VALORANT_ENTITLEMENTS_TOKEN=your-entitlements-token \
node server.js
```

In PowerShell:

```powershell
$env:VALORANT_SHARD = "na"
$env:VALORANT_ACCESS_TOKEN = "your-access-token"
$env:VALORANT_ENTITLEMENTS_TOKEN = "your-entitlements-token"
node server.js
```

For local UI testing without Riot credentials:

```bash
RR_BRIDGE_USE_MOCKS=1 node server.js
```

Then test:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/player
curl http://localhost:3000/wallet/mock-puuid
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
https://pd.{shard}.a.pvp.net/store/v1/wallet/{puuid}
```

maps to this local bridge route:

```text
GET /wallet/:puuid
```

You can also override the configured shard per request:

```text
GET /wallet/:puuid?shard=na
```

The private endpoint:

```text
https://glz-{region}-1.{shard}.a.pvp.net/parties/v1/parties/{party_id}/queues
```

maps to this local bridge route:

```text
GET /parties/:partyID/queues
```

The wallet handler proxies Riot when `VALORANT_SHARD`, `VALORANT_ACCESS_TOKEN`,
and `VALORANT_ENTITLEMENTS_TOKEN` are configured. Keep the iOS app talking to
the bridge routes so you can change the bridge internals without changing Swift
UI.
