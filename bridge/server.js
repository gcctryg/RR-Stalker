const http = require("http");
const https = require("https");
const path = require("path");
const { execFile } = require("child_process");
const { URL } = require("url");

const host = process.env.HOST || "0.0.0.0";
const port = Number(process.env.PORT || 3000);
const bridgeKey = process.env.RR_BRIDGE_KEY || "";
const valorantShard = process.env.VALORANT_SHARD || "";
const initialValorantAccessToken = process.env.VALORANT_ACCESS_TOKEN || "";
const initialValorantEntitlementsToken = process.env.VALORANT_ENTITLEMENTS_TOKEN || "";
const valorantClientPlatform = process.env.VALORANT_CLIENT_PLATFORM || "ew0KCSJwbGF0Zm9ybVR5cGUiOiAiUEMiLA0KCSJwbGF0Zm9ybU9TIjogIldpbmRvd3MiLA0KCSJwbGF0Zm9ybU9TVmVyc2lvbiI6ICIxMC4wLjE5MDQyLjEuMjU2LjY0Yml0IiwNCgkicGxhdGZvcm1DaGlwc2V0IjogIlVua25vd24iDQp9";
const initialValorantClientVersion = process.env.VALORANT_CLIENT_VERSION || "";
const initialValorantPUUID = process.env.VALORANT_PUUID || "";
const initialValorantGameName = process.env.VALORANT_GAME_NAME || "";
const initialValorantTagLine = process.env.VALORANT_TAG_LINE || "";
const riotClientPort = process.env.RIOT_CLIENT_PORT || "";
const riotClientPassword = process.env.RIOT_CLIENT_PASSWORD || "";
const riotLockfilePath = process.env.RIOT_LOCKFILE_PATH || "";
const valorantRemotingPort = process.env.VALORANT_REMOTING_PORT || "";
const valorantRemotingAuthToken = process.env.VALORANT_REMOTING_AUTH_TOKEN || "";
const useMocks = process.env.RR_BRIDGE_USE_MOCKS === "1";
const authState = {
  accessToken: initialValorantAccessToken,
  entitlementsToken: initialValorantEntitlementsToken,
  clientVersion: initialValorantClientVersion,
  puuid: initialValorantPUUID,
  gameName: initialValorantGameName,
  tagLine: initialValorantTagLine,
  refreshedAt: 0
};

function sendJSON(res, statusCode, body) {
  const payload = JSON.stringify(body, null, 2);

  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, X-RR-Bridge-Key",
    "Access-Control-Allow-Methods": "GET, OPTIONS"
  });
  res.end(payload);
}

function requireBridgeKey(req, res) {
  if (!bridgeKey) {
    return true;
  }

  if (req.headers["x-rr-bridge-key"] === bridgeKey) {
    return true;
  }

  sendJSON(res, 401, {
    error: "unauthorized",
    message: "Missing or incorrect X-RR-Bridge-Key header."
  });
  return false;
}

function runAuthHelper() {
  return new Promise((resolve, reject) => {
    if (!riotLockfilePath) {
      resolve(null);
      return;
    }

    execFile(
      process.execPath,
      [path.join(__dirname, "riot-auth.js"), riotLockfilePath],
      { windowsHide: true },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message));
          return;
        }

        try {
          resolve(JSON.parse(stdout));
        } catch {
          reject(new Error(`Could not parse auth helper output: ${stdout}`));
        }
      }
    );
  });
}

function applyAuthPayload(payload) {
  if (!payload) {
    return;
  }

  if (payload.accessToken) {
    authState.accessToken = payload.accessToken;
  }

  if (payload.entitlementsToken) {
    authState.entitlementsToken = payload.entitlementsToken;
  }

  if (payload.subject) {
    authState.puuid = payload.subject;
  }

  if (payload.gameName) {
    authState.gameName = payload.gameName;
  }

  if (payload.tagLine) {
    authState.tagLine = payload.tagLine;
  }

  if (payload.clientVersion) {
    authState.clientVersion = payload.clientVersion;
  }

  authState.refreshedAt = Date.now();
}

async function refreshAuthState({ force = false } = {}) {
  if (useMocks || !riotLockfilePath) {
    return;
  }

  if (!force && Date.now() - authState.refreshedAt < 30000) {
    return;
  }

  const payload = await runAuthHelper();
  applyAuthPayload(payload);
}

function getMockPlayer() {
  return {
    gameName: authState.gameName || "ExamplePlayer",
    tagLine: authState.tagLine || "NA1",
    puuid: authState.puuid || "mock-puuid",
    level: 111
  };
}

function getTokenPlayer() {
  if (!authState.gameName && !authState.tagLine && !authState.puuid) {
    return null;
  }

  return {
    gameName: authState.gameName || "Unknown",
    tagLine: authState.tagLine || "",
    puuid: authState.puuid || "mock-puuid",
    level: 111
  };
}

async function fetchAccountLevel(puuid, shard) {
  if (useMocks || !puuid || !shard || !authState.accessToken || !authState.entitlementsToken) {
    return null;
  }

  const accountXP = await fetchRiotJSON(`https://pd.${shard}.a.pvp.net/account-xp/v1/players/${encodeURIComponent(puuid)}`, {
    errorMessage: "Riot account XP request failed.",
    errorCode: "riot_account_xp_failed"
  });

  return accountXP?.Progress?.Level ?? null;
}

async function withAccountLevel(player, shard) {
  try {
    const level = await fetchAccountLevel(player.puuid, shard);

    if (typeof level === "number") {
      return {
        ...player,
        level
      };
    }
  } catch {
    // Keep player loading resilient if Account XP is temporarily unavailable.
  }

  return player;
}

function requestLocalRiotJSON(url, headers, errorCode = "riot_local_request_failed") {
  return new Promise((resolve, reject) => {
    const request = https.request(url, {
      method: "GET",
      headers,
      rejectUnauthorized: false
    }, (response) => {
      let text = "";

      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        text += chunk;
      });
      response.on("end", () => {
        let body;

        try {
          body = text ? JSON.parse(text) : {};
        } catch {
          body = { raw: text };
        }

        if (response.statusCode < 200 || response.statusCode > 299) {
          const error = new Error("Riot local request failed.");
          error.statusCode = response.statusCode;
          error.code = errorCode;
          error.body = body;
          reject(error);
          return;
        }

        resolve(body);
      });
    });

    request.on("error", reject);
    request.end();
  });
}

function getLocalRiotAuthHeaders() {
  const credentials = Buffer.from(`riot:${riotClientPassword}`, "ascii").toString("base64");
  return {
    Authorization: `Basic ${credentials}`
  };
}

function getValorantLocalAuthHeaders() {
  const credentials = Buffer.from(`riot:${valorantRemotingAuthToken}`, "ascii").toString("base64");
  return {
    Authorization: `Basic ${credentials}`
  };
}

async function fetchPlayerAlias() {
  const shard = valorantShard;
  await refreshAuthState({ force: true });

  if (useMocks || !riotClientPort || !riotClientPassword) {
    return withAccountLevel(getMockPlayer(), shard);
  }

  let body;

  try {
    body = await requestLocalRiotJSON(
      `https://127.0.0.1:${riotClientPort}/player-account/aliases/v1/active`,
      getLocalRiotAuthHeaders(),
      "riot_account_alias_failed"
    );
  } catch (error) {
    const tokenPlayer = getTokenPlayer();
    if (tokenPlayer) {
      return withAccountLevel(tokenPlayer, shard);
    }

    throw error;
  }

  return withAccountLevel({
    gameName: body.game_name || "Unknown",
    tagLine: body.tag_line || "",
    puuid: authState.puuid || "mock-puuid",
    level: 111
  }, shard);
}

function getMockFriends() {
  return {
    friends: [
      {
        puuid: "mock-friend-1",
        gameName: "FriendlyJett",
        tagLine: "NA1"
      },
      {
        puuid: "mock-friend-2",
        gameName: "PocketSage",
        tagLine: "GG"
      }
    ],
    source: "mock"
  };
}

function normalizeFriend(friend) {
  return {
    puuid: friend.puuid || friend.PUUID || friend.pid || friend.id || "",
    gameName: friend.game_name || friend.gameName || friend.name || friend.Name || "Unknown",
    tagLine: friend.game_tag || friend.gameTag || friend.tagLine || friend.tag_line || friend.TagLine || ""
  };
}

function normalizeFriendsBody(body) {
  const rawFriends = body.friends || body.Friends || body.data || [];

  return rawFriends
    .map(normalizeFriend)
    .filter((friend) => friend.puuid || friend.gameName !== "Unknown" || friend.tagLine);
}

async function fetchFriends() {
  if (useMocks) {
    return getMockFriends();
  }

  if (!riotClientPort && !valorantRemotingPort) {
    const error = new Error("Start the bridge with start-bridge.ps1 to load Riot friends.");
    error.statusCode = 503;
    error.code = "missing_local_riot_credentials";
    throw error;
  }

  const sources = [];

  if (riotClientPort && riotClientPassword) {
    sources.push({
      name: "riot-client",
      port: riotClientPort,
      headers: getLocalRiotAuthHeaders(),
      paths: ["/chat/v4/friends", "/chat/v4/friends/"]
    });
  }

  if (valorantRemotingPort && valorantRemotingAuthToken) {
    sources.push({
      name: "valorant-remoting",
      port: valorantRemotingPort,
      headers: getValorantLocalAuthHeaders(),
      paths: ["/chat/v4/friends", "/chat/v4/friends/"]
    });
  }

  const attempts = [];
  let body = null;
  let source = "";

  for (const localSource of sources) {
    for (const friendsPath of localSource.paths) {
      try {
        body = await requestLocalRiotJSON(
          `https://127.0.0.1:${localSource.port}${friendsPath}`,
          localSource.headers,
          "riot_friends_failed"
        );
        source = localSource.name;
        break;
      } catch (error) {
        attempts.push({
          source: localSource.name,
          path: friendsPath,
          error: error.body || error.message
        });
      }
    }

    if (body) {
      break;
    }
  }

  if (!body) {
    for (const localSource of sources) {
      try {
        const presenceBody = await requestLocalRiotJSON(
          `https://127.0.0.1:${localSource.port}/chat/v4/presences`,
          localSource.headers,
          "riot_presence_failed"
        );
        const seenPUUIDs = new Set();
        const friends = (presenceBody.presences || [])
          .filter((presence) => presence.puuid && presence.puuid !== authState.puuid)
          .filter((presence) => {
            if (seenPUUIDs.has(presence.puuid)) {
              return false;
            }

            seenPUUIDs.add(presence.puuid);
            return true;
          })
          .map(normalizeFriend);

        return {
          friends,
          source: `${localSource.name}:presences`
        };
      } catch (error) {
        attempts.push({
          source: localSource.name,
          path: "/chat/v4/presences",
          error: error.body || error.message
        });
      }
    }
  }

  if (!body) {
    let help = null;

    try {
      const helpSource = sources[0];
      help = await requestLocalRiotJSON(
        `https://127.0.0.1:${helpSource.port}/help`,
        helpSource.headers,
        "riot_help_failed"
      );
    } catch (error) {
      help = error.body || error.message;
    }

    const error = new Error("Riot local friends endpoints were not available.");
    error.statusCode = 502;
    error.code = "riot_friends_unavailable";
    error.body = {
      attempts,
      help
    };
    throw error;
  }

  const friends = normalizeFriendsBody(body);

  return {
    friends,
    source
  };
}

function getMockWallet(puuid) {
  return {
    puuid,
    Balances: {
      "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 1200,
      "e59aa87c-4cbf-517a-5983-6e81511be9b7": 45,
      "85ca954a-41f2-ce94-9b45-8ca3dd39a00d": 8000
    },
    source: "mock"
  };
}

function getMockStorefront() {
  return {
    offers: [
      {
        offerID: "mock-offer-1",
        itemID: "mock-item-1",
        name: "Mock Vandal Skin",
        iconURL: null,
        price: 1775,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
      },
      {
        offerID: "mock-offer-2",
        itemID: "mock-item-2",
        name: "Mock Phantom Skin",
        iconURL: null,
        price: 1775,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
      },
      {
        offerID: "mock-offer-3",
        itemID: "mock-item-3",
        name: "Mock Sheriff Skin",
        iconURL: null,
        price: 1275,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
      },
      {
        offerID: "mock-offer-4",
        itemID: "mock-item-4",
        name: "Mock Operator Skin",
        iconURL: null,
        price: 2175,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
      }
    ],
    durationRemainingInSeconds: 3600,
    source: "mock"
  };
}

function isValidShard(shard) {
  return /^[a-z0-9-]+$/i.test(shard);
}

function normalizeBearerToken(token) {
  return token.replace(/^Bearer\s+/i, "").trim();
}

function requireMatchingPUUID(puuid) {
  if (!authState.puuid || authState.puuid === puuid) {
    return;
  }

  const error = new Error("Requested PUUID does not match the current Riot auth token. Reload player data after switching accounts.");
  error.statusCode = 409;
  error.code = "puuid_mismatch";
  error.body = {
    requestedPUUID: puuid,
    currentPUUID: authState.puuid
  };
  throw error;
}

function getRiotHeaders() {
  const headers = {
    Authorization: `Bearer ${normalizeBearerToken(authState.accessToken)}`,
    "X-Riot-Entitlements-JWT": authState.entitlementsToken.trim()
  };

  if (valorantClientPlatform) {
    headers["X-Riot-ClientPlatform"] = valorantClientPlatform.trim();
  }

  if (authState.clientVersion) {
    headers["X-Riot-ClientVersion"] = authState.clientVersion.trim();
  }

  return headers;
}

const skinLevelCache = new Map();

async function fetchSkinLevel(itemID) {
  if (skinLevelCache.has(itemID)) {
    return skinLevelCache.get(itemID);
  }

  const response = await fetch(`https://valorant-api.com/v1/weapons/skinlevels/${encodeURIComponent(itemID)}`);
  if (!response.ok) {
    return null;
  }

  const body = await response.json();
  const skinLevel = body.data || null;
  skinLevelCache.set(itemID, skinLevel);
  return skinLevel;
}

async function fetchRiotJSON(url, options = {}) {
  const response = await fetch(url, {
    method: options.method || "GET",
    headers: {
      ...getRiotHeaders(),
      ...(options.headers || {})
    },
    body: options.body
  });

  const text = await response.text();
  let body;

  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }

  if (!response.ok) {
    const error = new Error(options.errorMessage || "Riot request failed.");
    error.statusCode = response.status;
    error.code = options.errorCode || "riot_request_failed";
    error.body = body;
    throw error;
  }

  return body;
}

async function fetchWallet(puuid, shard) {
  if (useMocks) {
    return getMockWallet(puuid);
  }

  await refreshAuthState();

  if (!shard) {
    const error = new Error("Set VALORANT_SHARD or pass ?shard=na to use wallet.");
    error.statusCode = 400;
    error.code = "missing_shard";
    throw error;
  }

  if (!isValidShard(shard)) {
    const error = new Error("Shard may only contain letters, numbers, and hyphens.");
    error.statusCode = 400;
    error.code = "invalid_shard";
    throw error;
  }

  if (!authState.accessToken || !authState.entitlementsToken) {
    const error = new Error("Set VALORANT_ACCESS_TOKEN and VALORANT_ENTITLEMENTS_TOKEN.");
    error.statusCode = 503;
    error.code = "missing_riot_credentials";
    throw error;
  }

  requireMatchingPUUID(puuid);

  return fetchRiotJSON(`https://pd.${shard}.a.pvp.net/store/v1/wallet/${encodeURIComponent(puuid)}`, {
    errorMessage: "Riot wallet request failed.",
    errorCode: "riot_wallet_failed"
  });
}

async function fetchStorefront(puuid, shard) {
  if (useMocks) {
    return getMockStorefront();
  }

  await refreshAuthState();

  if (!shard) {
    const error = new Error("Set VALORANT_SHARD or pass ?shard=na to use storefront.");
    error.statusCode = 400;
    error.code = "missing_shard";
    throw error;
  }

  if (!isValidShard(shard)) {
    const error = new Error("Shard may only contain letters, numbers, and hyphens.");
    error.statusCode = 400;
    error.code = "invalid_shard";
    throw error;
  }

  if (!authState.accessToken || !authState.entitlementsToken) {
    const error = new Error("Set VALORANT_ACCESS_TOKEN and VALORANT_ENTITLEMENTS_TOKEN.");
    error.statusCode = 503;
    error.code = "missing_riot_credentials";
    throw error;
  }

  requireMatchingPUUID(puuid);

  const storefront = await fetchRiotJSON(`https://pd.${shard}.a.pvp.net/store/v3/storefront/${encodeURIComponent(puuid)}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: "{}",
    errorMessage: "Riot storefront request failed.",
    errorCode: "riot_storefront_failed"
  });
  const layout = storefront.SkinsPanelLayout || {};
  const offers = layout.SingleItemStoreOffers || [];
  const enrichedOffers = await Promise.all(offers.slice(0, 4).map(async (offer) => {
    const reward = (offer.Rewards || [])[0] || {};
    const costEntries = Object.entries(offer.Cost || {});
    const [currencyID, price] = costEntries[0] || ["", 0];
    const skinLevel = reward.ItemID ? await fetchSkinLevel(reward.ItemID) : null;

    return {
      offerID: offer.OfferID,
      itemID: reward.ItemID || offer.OfferID,
      name: skinLevel?.displayName || reward.ItemID || offer.OfferID,
      iconURL: skinLevel?.displayIcon || null,
      price,
      currencyID
    };
  }));

  return {
    offers: enrichedOffers,
    durationRemainingInSeconds: layout.SingleItemOffersRemainingDurationInSeconds || 0
  };
}

function getMockPartyQueues(partyID) {
  return {
    partyID,
    queues: [
      "competitive",
      "unrated",
      "swiftplay",
      "deathmatch"
    ],
    source: "mock"
  };
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    sendJSON(res, 204, {});
    return;
  }

  const requestURL = new URL(req.url, `http://${req.headers.host}`);
  const pathParts = requestURL.pathname.split("/").filter(Boolean);

  if (req.method !== "GET") {
    sendJSON(res, 405, {
      error: "method_not_allowed",
      message: "Only GET requests are supported right now."
    });
    return;
  }

  if (requestURL.pathname === "/health") {
    sendJSON(res, 200, {
      ok: true,
      message: "RR Bridge is running"
    });
    return;
  }

  if (!requireBridgeKey(req, res)) {
    return;
  }

  if (requestURL.pathname === "/player") {
    try {
      const player = await fetchPlayerAlias();
      sendJSON(res, 200, player);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "player_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (pathParts[0] === "wallet" && pathParts[1]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const wallet = await fetchWallet(pathParts[1], shard);
      sendJSON(res, 200, wallet);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "wallet_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (pathParts[0] === "storefront" && pathParts[1]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const storefront = await fetchStorefront(pathParts[1], shard);
      sendJSON(res, 200, storefront);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "storefront_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (requestURL.pathname === "/friends") {
    try {
      const friends = await fetchFriends();
      sendJSON(res, 200, friends);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "friends_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (pathParts[0] === "parties" && pathParts[1] && pathParts[2] === "queues") {
    sendJSON(res, 200, getMockPartyQueues(pathParts[1]));
    return;
  }

  sendJSON(res, 404, {
    error: "not_found",
    routes: [
      "GET /health",
      "GET /player",
      "GET /wallet/:puuid",
      "GET /storefront/:puuid",
      "GET /friends",
      "GET /parties/:partyID/queues"
    ]
  });
});

server.listen(port, host, () => {
  console.log(`RR Bridge running at http://${host}:${port}`);
});
