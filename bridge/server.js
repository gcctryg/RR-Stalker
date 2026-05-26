const http = require("http");
const https = require("https");
const { URL } = require("url");

const host = process.env.HOST || "0.0.0.0";
const port = Number(process.env.PORT || 3000);
const bridgeKey = process.env.RR_BRIDGE_KEY || "";
const valorantShard = process.env.VALORANT_SHARD || "";
const valorantAccessToken = process.env.VALORANT_ACCESS_TOKEN || "";
const valorantEntitlementsToken = process.env.VALORANT_ENTITLEMENTS_TOKEN || "";
const valorantClientPlatform = process.env.VALORANT_CLIENT_PLATFORM || "ew0KCSJwbGF0Zm9ybVR5cGUiOiAiUEMiLA0KCSJwbGF0Zm9ybU9TIjogIldpbmRvd3MiLA0KCSJwbGF0Zm9ybU9TVmVyc2lvbiI6ICIxMC4wLjE5MDQyLjEuMjU2LjY0Yml0IiwNCgkicGxhdGZvcm1DaGlwc2V0IjogIlVua25vd24iDQp9";
const valorantClientVersion = process.env.VALORANT_CLIENT_VERSION || "";
const valorantPUUID = process.env.VALORANT_PUUID || "";
const valorantGameName = process.env.VALORANT_GAME_NAME || "";
const valorantTagLine = process.env.VALORANT_TAG_LINE || "";
const riotClientPort = process.env.RIOT_CLIENT_PORT || "";
const riotClientPassword = process.env.RIOT_CLIENT_PASSWORD || "";
const useMocks = process.env.RR_BRIDGE_USE_MOCKS === "1";

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

function getMockPlayer() {
  return {
    gameName: valorantGameName || "ExamplePlayer",
    tagLine: valorantTagLine || "NA1",
    puuid: valorantPUUID || "mock-puuid",
    level: 111
  };
}

function getTokenPlayer() {
  if (!valorantGameName && !valorantTagLine && !valorantPUUID) {
    return null;
  }

  return {
    gameName: valorantGameName || "Unknown",
    tagLine: valorantTagLine || "",
    puuid: valorantPUUID || "mock-puuid",
    level: 111
  };
}

function requestLocalRiotJSON(url, headers) {
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
          const error = new Error("Riot account alias request failed.");
          error.statusCode = response.statusCode;
          error.code = "riot_account_alias_failed";
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

async function fetchPlayerAlias() {
  if (useMocks || !riotClientPort || !riotClientPassword) {
    return getMockPlayer();
  }

  const credentials = Buffer.from(`riot:${riotClientPassword}`, "ascii").toString("base64");
  let body;

  try {
    body = await requestLocalRiotJSON(
      `https://127.0.0.1:${riotClientPort}/player-account/aliases/v1/active`,
      {
        Authorization: `Basic ${credentials}`
      }
    );
  } catch (error) {
    const tokenPlayer = getTokenPlayer();
    if (tokenPlayer) {
      return tokenPlayer;
    }

    throw error;
  }

  return {
    gameName: body.game_name || "Unknown",
    tagLine: body.tag_line || "",
    puuid: valorantPUUID || "mock-puuid",
    level: 111
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

function getRiotHeaders() {
  const headers = {
    Authorization: `Bearer ${normalizeBearerToken(valorantAccessToken)}`,
    "X-Riot-Entitlements-JWT": valorantEntitlementsToken.trim()
  };

  if (valorantClientPlatform) {
    headers["X-Riot-ClientPlatform"] = valorantClientPlatform.trim();
  }

  if (valorantClientVersion) {
    headers["X-Riot-ClientVersion"] = valorantClientVersion.trim();
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

  if (!valorantAccessToken || !valorantEntitlementsToken) {
    const error = new Error("Set VALORANT_ACCESS_TOKEN and VALORANT_ENTITLEMENTS_TOKEN.");
    error.statusCode = 503;
    error.code = "missing_riot_credentials";
    throw error;
  }

  return fetchRiotJSON(`https://pd.${shard}.a.pvp.net/store/v1/wallet/${encodeURIComponent(puuid)}`, {
    errorMessage: "Riot wallet request failed.",
    errorCode: "riot_wallet_failed"
  });
}

async function fetchStorefront(puuid, shard) {
  if (useMocks) {
    return getMockStorefront();
  }

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

  if (!valorantAccessToken || !valorantEntitlementsToken) {
    const error = new Error("Set VALORANT_ACCESS_TOKEN and VALORANT_ENTITLEMENTS_TOKEN.");
    error.statusCode = 503;
    error.code = "missing_riot_credentials";
    throw error;
  }

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
      "GET /parties/:partyID/queues"
    ]
  });
});

server.listen(port, host, () => {
  console.log(`RR Bridge running at http://${host}:${port}`);
});
