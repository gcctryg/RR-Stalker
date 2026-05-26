const http = require("http");
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
    gameName: "ExamplePlayer",
    tagLine: "NA1",
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

  const url = `https://pd.${shard}.a.pvp.net/store/v1/wallet/${encodeURIComponent(puuid)}`;
  const response = await fetch(url, {
    headers: getRiotHeaders()
  });

  const text = await response.text();
  let body;

  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }

  if (!response.ok) {
    const error = new Error("Riot wallet request failed.");
    error.statusCode = response.status;
    error.code = "riot_wallet_failed";
    error.body = body;
    throw error;
  }

  return body;
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
    sendJSON(res, 200, getMockPlayer());
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
      "GET /parties/:partyID/queues"
    ]
  });
});

server.listen(port, host, () => {
  console.log(`RR Bridge running at http://${host}:${port}`);
});
