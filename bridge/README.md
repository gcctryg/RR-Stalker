# RR Bridge

Tiny local bridge API for the iOS app.

## Run

On Windows, start Riot Client and log in, then run:

```powershell
.\start-bridge.ps1 -Shard na
```

The script reads the Riot Client lockfile, fetches fresh access and entitlements
tokens from the local client, sets the bridge environment variables, and starts
the bridge. It also passes your token subject as `VALORANT_PUUID`, so `/player`
can return your real PUUID for the iOS wallet request. The bridge also uses the
lockfile credentials to call Riot's local account alias endpoint so `/player`
can return your real game name and tagline.

Launch VALORANT to the main menu before starting the bridge if you want friends
or other local chat data. The script reads VALORANT's remoting port/token from
the running game process for those endpoints.

If PowerShell blocks the script, run this once from the `bridge` folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run:

```powershell
.\start-bridge.ps1 -Shard na
```

Manual startup still works too:

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
$env:VALORANT_CLIENT_PLATFORM = "optional-value-from-insomnia"
$env:VALORANT_CLIENT_VERSION = "optional-value-from-insomnia"
node server.js
```

If Riot returns `INVALID_HEADERS`, copy these request headers from the working
Insomnia request too:

```text
X-Riot-ClientPlatform
X-Riot-ClientVersion
```

`VALORANT_ACCESS_TOKEN` may be pasted either with or without the `Bearer`
prefix.

For local UI testing without Riot credentials:

```bash
RR_BRIDGE_USE_MOCKS=1 node server.js
```

Then test:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/player
curl http://localhost:3000/wallet/mock-puuid
curl http://localhost:3000/storefront/mock-puuid
curl http://localhost:3000/loadout/mock-puuid
curl http://localhost:3000/friends
curl "http://localhost:3000/friends/mmr?puuids=mock-puuid"
curl http://localhost:3000/friends/first-mmr
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
https://pd.{shard}.a.pvp.net/store/v3/storefront/{puuid}
```

maps to this local bridge route:

```text
GET /storefront/:puuid
```

The bridge sends Riot a `POST` request with an empty JSON object body.

The private endpoint:

```text
https://pd.{shard}.a.pvp.net/personalization/v2/players/{puuid}/playerloadout
```

maps to this local bridge route:

```text
GET /loadout/:puuid
```

The bridge enriches equipped weapons with public weapon and skin assets from
Valorant-API so the iOS app can display the current loadout with images.

The private endpoint:

```text
https://pd.{shard}.a.pvp.net/mmr/v1/players/{puuid}
```

maps to these local bridge test routes:

```text
GET /mmr/:puuid
GET /friends/first-mmr
```

`/friends/first-mmr` loads the first friend from `/friends`, then tries the MMR
endpoint with that friend's PUUID.

The private endpoint:

```text
https://127.0.0.1:{port}/chat/v4/friends
```

maps to this local bridge route:

```text
GET /friends
```

`/friends` returns names and PUUIDs only. Use the selected/favorite PUUIDs with
this local bridge route to fetch ranks without rate-limiting the whole friend
list:

```text
GET /friends/mmr?puuids=:puuid,:puuid
```

The iOS app saves favorite friend selections per signed-in player account, then
only calls `/friends/mmr` for those favorite PUUIDs. The bridge enriches MMR
results with rank names and icons from Valorant-API's public competitive tiers
endpoint:

```text
https://valorant-api.com/v1/competitivetiers
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
