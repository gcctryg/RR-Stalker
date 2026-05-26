const http = require("http");
const { URL } = require("url");

const host = process.env.HOST || "0.0.0.0";
const port = Number(process.env.PORT || 3000);
const bridgeKey = process.env.RR_BRIDGE_KEY || "";

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
    puuid: "mock-puuid",
    level: 123
  };
}

function getMockAccountXP(puuid) {
  return {
    puuid,
    level: 123,
    xp: 4567,
    nextLevelXP: 5000,
    source: "mock"
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
    sendJSON(res, 200, getMockPlayer());
    return;
  }

  if (pathParts[0] === "account-xp" && pathParts[1]) {
    sendJSON(res, 200, getMockAccountXP(pathParts[1]));
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
      "GET /account-xp/:puuid",
      "GET /parties/:partyID/queues"
    ]
  });
});

server.listen(port, host, () => {
  console.log(`RR Bridge running at http://${host}:${port}`);
});
