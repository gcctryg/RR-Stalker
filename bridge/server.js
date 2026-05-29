const http = require("http");
const https = require("https");
const path = require("path");
const fs = require("fs");
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
const cacheDirectory = path.join(__dirname, ".cache");
const itemTypeIDs = {
  sprays: "d5f120f8-ff8c-4aac-92ea-f2b5acbe9475",
  cards: "3f296c07-64c3-494c-923b-fe692a4fa1bd",
  skins: "e7c63390-eda7-46e0-bb7a-a6abdacd2433",
  skinVariants: "3ad1b2b2-acdb-4524-852f-954a76ddae0a",
  buddies: "dd3bf334-87f3-40bd-b043-682a57a8dc3a"
};
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
    "Access-Control-Allow-Methods": "GET, PUT, OPTIONS"
  });
  res.end(payload);
}

function readJSONBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";

    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1000000) {
        reject(new Error("Request body is too large."));
        req.destroy();
      }
    });

    req.on("end", () => {
      if (!body.trim()) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(body));
      } catch {
        const error = new Error("Request body must be valid JSON.");
        error.statusCode = 400;
        error.code = "invalid_json";
        reject(error);
      }
    });

    req.on("error", reject);
  });
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

function readCachedJSON(name) {
  try {
    return JSON.parse(fs.readFileSync(path.join(cacheDirectory, `${name}.json`), "utf8"));
  } catch {
    return null;
  }
}

function writeCachedJSON(name, body) {
  try {
    fs.mkdirSync(cacheDirectory, { recursive: true });
    fs.writeFileSync(
      path.join(cacheDirectory, `${name}.json`),
      JSON.stringify({ savedAt: Date.now(), body }),
      "utf8"
    );
  } catch {
    // Cache writes should never break the bridge.
  }
}

async function fetchValorantAPIJSON(url, cacheName, options = {}) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      const error = new Error(`Valorant-API returned HTTP ${response.status}`);
      error.statusCode = response.status;
      throw error;
    }

    const body = await response.json();
    writeCachedJSON(cacheName, body);
    return body;
  } catch (error) {
    const cached = readCachedJSON(cacheName)?.body || null;
    if (options.returnMeta) {
      return {
        body: cached,
        errorStatus: error.statusCode || null,
        usedCache: Boolean(cached)
      };
    }

    return cached;
  }
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

async function fetchLocalPresences() {
  if (!riotClientPort && !valorantRemotingPort) {
    const error = new Error("Start the bridge with start-bridge.ps1 to load Riot presences.");
    error.statusCode = 503;
    error.code = "missing_local_riot_credentials";
    throw error;
  }

  const sources = [];

  if (riotClientPort && riotClientPassword) {
    sources.push({
      name: "riot-client",
      port: riotClientPort,
      headers: getLocalRiotAuthHeaders()
    });
  }

  if (valorantRemotingPort && valorantRemotingAuthToken) {
    sources.push({
      name: "valorant-remoting",
      port: valorantRemotingPort,
      headers: getValorantLocalAuthHeaders()
    });
  }

  const attempts = [];

  for (const source of sources) {
    try {
      const body = await requestLocalRiotJSON(
        `https://127.0.0.1:${source.port}/chat/v4/presences`,
        source.headers,
        "riot_presence_failed"
      );

      return {
        presences: body.presences || [],
        source: source.name
      };
    } catch (error) {
      attempts.push({
        source: source.name,
        path: "/chat/v4/presences",
        error: error.body || error.message
      });
    }
  }

  const error = new Error("Riot local presence endpoint was not available.");
  error.statusCode = 502;
  error.code = "riot_presence_unavailable";
  error.body = { attempts };
  throw error;
}

async function fetchFriendsStatus(puuids) {
  const uniquePUUIDs = [...new Set(puuids.map((puuid) => puuid.trim()).filter(Boolean))];

  if (useMocks) {
    return {
      statuses: uniquePUUIDs.map((puuid, index) => ({
        puuid,
        isOnline: index % 2 === 0,
        availability: index % 2 === 0 ? "chat" : "offline",
        state: index % 2 === 0 ? "chat" : "offline",
        product: index % 2 === 0 ? "valorant" : ""
      })),
      missing: [],
      source: "mock",
      presenceCount: uniquePUUIDs.length
    };
  }

  const { presences, source } = await fetchLocalPresences();
  const requestedPUUIDs = new Set(uniquePUUIDs);
  const presenceByPUUID = new Map(
    presences
      .filter((presence) => requestedPUUIDs.has(presence.puuid))
      .map((presence) => [presence.puuid, presence])
  );
  const missing = [];
  const statuses = uniquePUUIDs.map((puuid) => {
    const presence = presenceByPUUID.get(puuid);

    if (!presence) {
      missing.push({ puuid, reason: "presence_not_found" });
      return {
        puuid,
        isOnline: false,
        availability: "offline",
        state: "offline",
        product: ""
      };
    }

    const state = (presence.state || "").toLowerCase();
    const product = (presence.product || "").toLowerCase();
    const isValorantPresence = product === "valorant";
    const isOnline = isValorantPresence && ["chat", "dnd", "away"].includes(state);

    return {
      puuid,
      isOnline,
      availability: state || "unknown",
      state: state || "unknown",
      product
    };
  });

  return {
    statuses,
    missing,
    source,
    presenceCount: presences.length
  };
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
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741",
        contentTierName: "Premium Edition",
        contentTierColor: "d1548d33",
        contentTierIconURL: "https://media.valorant-api.com/contenttiers/60bca009-4182-7998-dee7-b8a2558dc369/displayicon.png"
      },
      {
        offerID: "mock-offer-2",
        itemID: "mock-item-2",
        name: "Mock Phantom Skin",
        iconURL: null,
        price: 1775,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741",
        contentTierName: "Deluxe Edition",
        contentTierColor: "00958733",
        contentTierIconURL: "https://media.valorant-api.com/contenttiers/0cebb8be-46d7-c12a-d306-e9907bfc5a25/displayicon.png"
      },
      {
        offerID: "mock-offer-3",
        itemID: "mock-item-3",
        name: "Mock Sheriff Skin",
        iconURL: null,
        price: 1275,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741",
        contentTierName: "Select Edition",
        contentTierColor: "5a9fe233",
        contentTierIconURL: "https://media.valorant-api.com/contenttiers/12683d76-48d7-84a3-4e09-6985794f0445/displayicon.png"
      },
      {
        offerID: "mock-offer-4",
        itemID: "mock-item-4",
        name: "Mock Operator Skin",
        iconURL: null,
        price: 2175,
        currencyID: "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741",
        contentTierName: "Ultra Edition",
        contentTierColor: "fad66333",
        contentTierIconURL: "https://media.valorant-api.com/contenttiers/411e4a55-4e59-7757-41f0-86a53f101bb5/displayicon.png"
      }
    ],
    durationRemainingInSeconds: 3600,
    source: "mock"
  };
}

function getMockLoadout(puuid) {
  return {
    subject: puuid,
    guns: [
      {
        id: "mock-vandal",
        weaponName: "Vandal",
        skinName: "Prime Vandal",
        displayName: "Prime Vandal",
        iconURL: "https://media.valorant-api.com/weaponskins/9f8688b6-4c1f-1140-bcfd-6babb8156fe8/displayicon.png",
        category: "Rifles",
        skinID: "mock-prime-vandal",
        skinLevelID: "mock-prime-vandal-level",
        chromaID: "mock-prime-vandal-chroma",
        charmID: "mock-buddy",
        charmLevelID: "mock-buddy-level",
        charmName: "Mock Buddy",
        charmIconURL: "https://media.valorant-api.com/buddylevels/49e6eea8-4ee4-2859-02a8-3a9dca3a1c96/displayicon.png"
      },
      {
        id: "mock-phantom",
        weaponName: "Phantom",
        skinName: "Oni Phantom",
        displayName: "Oni Phantom",
        iconURL: "https://media.valorant-api.com/weaponskins/da48adf0-4b7c-9b2d-6ea0-2a80f8d4fbb5/displayicon.png",
        category: "Rifles",
        skinID: "mock-oni-phantom",
        skinLevelID: "mock-oni-phantom-level",
        chromaID: "mock-oni-phantom-chroma"
      },
      {
        id: "mock-classic",
        weaponName: "Classic",
        skinName: "Classic",
        displayName: "Classic",
        iconURL: "https://media.valorant-api.com/weapons/29a0cfab-485b-f5d5-779a-b59f85e204a8/displayicon.png",
        category: "Sidearms",
        skinID: "mock-classic",
        skinLevelID: "mock-classic-level",
        chromaID: "mock-classic-chroma"
      }
    ],
    identity: {
      accountLevel: 111,
      hideAccountLevel: false
    }
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

async function ensureRiotReady(shard, purpose) {
  await refreshAuthState();

  if (!shard) {
    const error = new Error(`Set VALORANT_SHARD or pass ?shard=na to use ${purpose}.`);
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
const skinChromaCache = new Map();
const skinCache = new Map();
const weaponAssetCache = {
  loadedAt: 0,
  weaponsByID: new Map(),
  skinLevelsByID: new Map(),
  skinChromasByID: new Map(),
  skinsByID: new Map()
};
const competitiveTierCache = {
  loadedAt: 0,
  tiers: new Map()
};
const contentTierCache = {
  loadedAt: 0,
  tiersByID: new Map()
};
const seasonCache = {
  loadedAt: 0,
  seasonsByID: new Map()
};
const sprayAssetCache = {
  loadedAt: 0,
  spraysByID: new Map()
};
const playerCardAssetCache = {
  loadedAt: 0,
  cardsByID: new Map()
};
const buddyAssetCache = {
  loadedAt: 0,
  buddiesByID: new Map(),
  buddyLevelsByID: new Map()
};

async function fetchSkinLevel(itemID) {
  if (skinLevelCache.has(itemID)) {
    return skinLevelCache.get(itemID);
  }

  const weaponAssets = await fetchWeaponAssets();
  if (weaponAssets.skinLevelsByID.has(itemID)) {
    const skinLevel = weaponAssets.skinLevelsByID.get(itemID);
    skinLevelCache.set(itemID, skinLevel);
    return skinLevel;
  }

  const body = await fetchValorantAPIJSON(
    `https://valorant-api.com/v1/weapons/skinlevels/${encodeURIComponent(itemID)}`,
    `skinlevel-${itemID}`
  );
  if (!body) {
    return null;
  }

  const skinLevel = body.data || null;
  skinLevelCache.set(itemID, skinLevel);
  return skinLevel;
}

async function fetchWeaponAssets() {
  if (Date.now() - weaponAssetCache.loadedAt < 3600000 && weaponAssetCache.weaponsByID.size > 0) {
    return weaponAssetCache;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/weapons", "weapons");
  if (!body) {
    return weaponAssetCache;
  }

  const weaponsByID = new Map();
  const skinLevelsByID = new Map();
  const skinChromasByID = new Map();
  const skinsByID = new Map();

  for (const weapon of body.data || []) {
    weaponsByID.set(weapon.uuid, weapon);

    for (const skin of weapon.skins || []) {
      skinsByID.set(skin.uuid, skin);

      for (const level of skin.levels || []) {
        skinLevelsByID.set(level.uuid, {
          ...level,
          skinContentTierUuid: skin.contentTierUuid || null
        });
      }

      for (const chroma of skin.chromas || []) {
        skinChromasByID.set(chroma.uuid, chroma);
      }
    }
  }

  weaponAssetCache.loadedAt = Date.now();
  weaponAssetCache.weaponsByID = weaponsByID;
  weaponAssetCache.skinLevelsByID = skinLevelsByID;
  weaponAssetCache.skinChromasByID = skinChromasByID;
  weaponAssetCache.skinsByID = skinsByID;
  return weaponAssetCache;
}

async function fetchSprayAssets() {
  if (Date.now() - sprayAssetCache.loadedAt < 3600000 && sprayAssetCache.spraysByID.size > 0) {
    return sprayAssetCache;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/sprays", "sprays");
  if (!body) {
    return sprayAssetCache;
  }

  sprayAssetCache.loadedAt = Date.now();
  sprayAssetCache.spraysByID = new Map((body.data || []).map((spray) => [spray.uuid, spray]));
  return sprayAssetCache;
}

async function fetchPlayerCardAssets() {
  if (Date.now() - playerCardAssetCache.loadedAt < 3600000 && playerCardAssetCache.cardsByID.size > 0) {
    return playerCardAssetCache;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/playercards", "playercards");
  if (!body) {
    return playerCardAssetCache;
  }

  playerCardAssetCache.loadedAt = Date.now();
  playerCardAssetCache.cardsByID = new Map((body.data || []).map((card) => [card.uuid, card]));
  return playerCardAssetCache;
}

async function fetchBuddyAssets() {
  if (Date.now() - buddyAssetCache.loadedAt < 3600000 && buddyAssetCache.buddiesByID.size > 0) {
    return buddyAssetCache;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/buddies", "buddies");
  if (!body) {
    return buddyAssetCache;
  }

  const buddiesByID = new Map();
  const buddyLevelsByID = new Map();

  for (const buddy of body.data || []) {
    buddiesByID.set(buddy.uuid, buddy);

    for (const level of buddy.levels || []) {
      buddyLevelsByID.set(level.uuid, {
        ...level,
        buddy
      });
    }
  }

  buddyAssetCache.loadedAt = Date.now();
  buddyAssetCache.buddiesByID = buddiesByID;
  buddyAssetCache.buddyLevelsByID = buddyLevelsByID;
  return buddyAssetCache;
}

async function fetchSkinChroma(chromaID) {
  if (!chromaID) {
    return null;
  }

  if (skinChromaCache.has(chromaID)) {
    return skinChromaCache.get(chromaID);
  }

  const weaponAssets = await fetchWeaponAssets();
  if (weaponAssets.skinChromasByID.has(chromaID)) {
    const chroma = weaponAssets.skinChromasByID.get(chromaID);
    skinChromaCache.set(chromaID, chroma);
    return chroma;
  }

  return null;
}

function getSkinByID(skinID) {
  const skin = weaponAssetCache.skinsByID.get(skinID) || null;
  if (skinID && skin) {
    skinCache.set(skinID, skin);
  }

  return skinID ? skinCache.get(skinID) || null : null;
}

function firstURL(...urls) {
  return urls.find((url) => typeof url === "string" && url.length > 0) || null;
}

function normalizeWeaponCategory(category) {
  const rawCategory = (category || "").split("::").at(-1) || "Weapons";
  return rawCategory
    .toLowerCase()
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

async function fetchCompetitiveTierAssets() {
  if (Date.now() - competitiveTierCache.loadedAt < 3600000 && competitiveTierCache.tiers.size > 0) {
    return competitiveTierCache.tiers;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/competitivetiers", "competitivetiers");
  if (!body) {
    return competitiveTierCache.tiers;
  }

  const tierSets = Array.isArray(body.data) ? body.data : [];
  const latestTierSet = tierSets.at(-1);
  const tiers = new Map();

  for (const tier of latestTierSet?.tiers || []) {
    tiers.set(tier.tier, {
      name: formatRankName(tier.tierName),
      smallIcon: tier.smallIcon || null,
      largeIcon: tier.largeIcon || tier.smallIcon || null,
      rankTriangleDownIcon: tier.rankTriangleDownIcon || null,
      rankTriangleUpIcon: tier.rankTriangleUpIcon || null
    });
  }

  competitiveTierCache.loadedAt = Date.now();
  competitiveTierCache.tiers = tiers;
  return tiers;
}

async function fetchContentTierAssets() {
  if (Date.now() - contentTierCache.loadedAt < 3600000 && contentTierCache.tiersByID.size > 0) {
    return contentTierCache.tiersByID;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/contenttiers", "contenttiers");
  if (!body) {
    return contentTierCache.tiersByID;
  }

  const tiersByID = new Map();
  for (const tier of body.data || []) {
    tiersByID.set(tier.uuid, {
      name: tier.displayName || tier.devName || "",
      color: tier.highlightColor || null,
      iconURL: tier.displayIcon || null
    });
  }

  contentTierCache.loadedAt = Date.now();
  contentTierCache.tiersByID = tiersByID;
  return tiersByID;
}

async function fetchSeasonAssets() {
  if (Date.now() - seasonCache.loadedAt < 3600000 && seasonCache.seasonsByID.size > 0) {
    return seasonCache.seasonsByID;
  }

  const body = await fetchValorantAPIJSON("https://valorant-api.com/v1/seasons", "seasons");
  if (!body) {
    return seasonCache.seasonsByID;
  }

  const seasonsByID = new Map();
  for (const season of body.data || []) {
    seasonsByID.set(season.uuid, {
      name: season.displayName || season.devName || "Unknown Act",
      type: season.type || "",
      parentUUID: season.parentUuid || season.parentUUID || "",
      startTime: season.startTime || "",
      endTime: season.endTime || ""
    });
  }

  seasonCache.loadedAt = Date.now();
  seasonCache.seasonsByID = seasonsByID;
  return seasonsByID;
}

function formatRankName(rankName) {
  if (!rankName) {
    return "";
  }

  return rankName.toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase());
}

async function withCompetitiveTierAssets(mmrInfo) {
  const tiers = await fetchCompetitiveTierAssets();
  const seasons = await fetchSeasonAssets();
  const tier = tiers.get(mmrInfo.competitiveTier);
  const actRankBadgeCells = (mmrInfo.actRankBadgeCells || []).map((cell) => {
    const cellTier = tiers.get(cell.tier);

    return {
      ...cell,
      rankTriangleDownIconURL: cellTier?.rankTriangleDownIcon || null,
      rankTriangleUpIconURL: cellTier?.rankTriangleUpIcon || null
    };
  });
  const acts = (mmrInfo.acts || []).map((act) => ({
    ...act,
    ...(() => {
      const season = seasons.get(act.seasonID);
      const parent = season?.parentUUID ? seasons.get(season.parentUUID) : null;
      const seasonName = season?.name || act.name || "Unknown Act";
      const name = parent?.name ? `${parent.name} ${seasonName}` : seasonName;

      return {
        name,
        type: season?.type || act.type || "",
        startTime: season?.startTime || act.startTime || "",
        endTime: season?.endTime || act.endTime || "",
        badgeCells: (act.badgeCells || []).map((cell) => {
          const cellTier = tiers.get(cell.tier);

          return {
            ...cell,
            rankTriangleDownIconURL: cellTier?.rankTriangleDownIcon || null,
            rankTriangleUpIconURL: cellTier?.rankTriangleUpIcon || null
          };
        })
      };
    })()
  }))
    .sort((a, b) => {
      if (a.isCurrent !== b.isCurrent) {
        return a.isCurrent ? -1 : 1;
      }

      return (b.startTime || "").localeCompare(a.startTime || "");
    });

  return {
    ...mmrInfo,
    rankName: tier?.name || (mmrInfo.competitiveTier > 0 ? `Tier ${mmrInfo.competitiveTier}` : "Unrated"),
    rankIconURL: tier?.largeIcon || tier?.smallIcon || null,
    actRankBadgeCells,
    acts
  };
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
  const contentTiers = await fetchContentTierAssets();
  const enrichedOffers = await Promise.all(offers.slice(0, 4).map(async (offer) => {
    const reward = (offer.Rewards || [])[0] || {};
    const costEntries = Object.entries(offer.Cost || {});
    const [currencyID, price] = costEntries[0] || ["", 0];
    const skinLevel = reward.ItemID ? await fetchSkinLevel(reward.ItemID) : null;
    const contentTierUUID = skinLevel?.skinContentTierUuid || skinLevel?.contentTierUuid || null;
    const contentTier = contentTierUUID ? contentTiers.get(contentTierUUID) : null;

    return {
      offerID: offer.OfferID,
      itemID: reward.ItemID || offer.OfferID,
      name: skinLevel?.displayName || reward.ItemID || offer.OfferID,
      iconURL: skinLevel?.displayIcon || null,
      price,
      currencyID,
      contentTierUUID,
      contentTierName: contentTier?.name || null,
      contentTierColor: contentTier?.color || null,
      contentTierIconURL: contentTier?.iconURL || null
    };
  }));

  return {
    offers: enrichedOffers,
    durationRemainingInSeconds: layout.SingleItemOffersRemainingDurationInSeconds || 0
  };
}

async function fetchPlayerLoadout(puuid, shard) {
  if (useMocks) {
    return getMockLoadout(puuid);
  }

  await refreshAuthState();

  if (!shard) {
    const error = new Error("Set VALORANT_SHARD or pass ?shard=na to use player loadout.");
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

  const [loadout, weaponAssets, contentTiers, buddyAssets] = await Promise.all([
    fetchRiotJSON(`https://pd.${shard}.a.pvp.net/personalization/v2/players/${encodeURIComponent(puuid)}/playerloadout`, {
      errorMessage: "Riot player loadout request failed.",
      errorCode: "riot_player_loadout_failed"
    }),
    fetchWeaponAssets(),
    fetchContentTierAssets(),
    fetchBuddyAssets()
  ]);

  const guns = await Promise.all((loadout.Guns || []).map(async (gun) => {
    const weapon = weaponAssets.weaponsByID.get(gun.ID) || {};
    const skinLevel = gun.SkinLevelID ? await fetchSkinLevel(gun.SkinLevelID) : null;
    const skinChroma = await fetchSkinChroma(gun.ChromaID);
    const skin = getSkinByID(gun.SkinID);
    const skinName = skin?.displayName || skinLevel?.displayName || weapon.displayName || gun.SkinLevelID || gun.SkinID;
    const contentTierUUID = skin?.contentTierUuid || skinLevel?.skinContentTierUuid || skinLevel?.contentTierUuid || null;
    const contentTier = contentTierUUID ? contentTiers.get(contentTierUUID) : null;
    const charmID = gun.CharmID || null;
    const charmLevelID = gun.CharmLevelID || null;
    const charmLevel = (charmLevelID ? buddyAssets.buddyLevelsByID.get(charmLevelID) : null)
      || (charmID ? buddyAssets.buddyLevelsByID.get(charmID) : null);
    const charm = (charmID ? buddyAssets.buddiesByID.get(charmID) : null) || charmLevel?.buddy || null;

    return {
      id: gun.ID,
      weaponName: weapon.displayName || gun.ID,
      skinName,
      displayName: skinName,
      iconURL: firstURL(
        skinLevel?.displayIcon,
        skinChroma?.fullRender,
        skinChroma?.displayIcon,
        skin?.displayIcon,
        weapon.displayIcon
      ),
      category: normalizeWeaponCategory(weapon.category),
      skinID: gun.SkinID,
      skinLevelID: gun.SkinLevelID,
      chromaID: gun.ChromaID,
      charmID,
      charmLevelID,
      charmName: charm?.displayName || charmLevel?.displayName || null,
      charmIconURL: firstURL(charmLevel?.displayIcon, charm?.displayIcon),
      contentTierUUID,
      contentTierName: contentTier?.name || null,
      contentTierColor: contentTier?.color || null,
      contentTierIconURL: contentTier?.iconURL || null
    };
  }));

  return {
    subject: loadout.Subject,
    guns: guns.sort((a, b) => {
      if (a.category === b.category) {
        return a.weaponName.localeCompare(b.weaponName);
      }

      return a.category.localeCompare(b.category);
    }),
    identity: {
      playerCardID: loadout.Identity?.PlayerCardID || "",
      playerTitleID: loadout.Identity?.PlayerTitleID || "",
      accountLevel: loadout.Identity?.AccountLevel || 0,
      preferredLevelBorderID: loadout.Identity?.PreferredLevelBorderID || "",
      hideAccountLevel: Boolean(loadout.Identity?.HideAccountLevel)
    },
    incognito: Boolean(loadout.Incognito)
  };
}

async function fetchRawPlayerLoadout(puuid, shard) {
  await ensureRiotReady(shard, "player loadout");
  requireMatchingPUUID(puuid);

  return fetchRiotJSON(`https://pd.${shard}.a.pvp.net/personalization/v2/players/${encodeURIComponent(puuid)}/playerloadout`, {
    errorMessage: "Riot player loadout request failed.",
    errorCode: "riot_player_loadout_failed"
  });
}

async function fetchOwnedItemIDs(puuid, shard, itemTypeID) {
  await ensureRiotReady(shard, "owned items");
  requireMatchingPUUID(puuid);

  const body = await fetchRiotJSON(`https://pd.${shard}.a.pvp.net/store/v1/entitlements/${encodeURIComponent(puuid)}/${itemTypeID}`, {
    errorMessage: "Riot owned items request failed.",
    errorCode: "riot_owned_items_failed"
  });
  const entitlements = Array.isArray(body?.Entitlements)
    ? body.Entitlements
    : Array.isArray(body?.EntitlementsByTypes)
      ? body.EntitlementsByTypes.flatMap((entry) => entry.Entitlements || [])
      : Object.values(body?.EntitlementsByTypes || {}).flatMap((entry) => entry.Entitlements || entry || []);

  return new Set(entitlements.map((item) => item.ItemID).filter(Boolean));
}

function skinIsOwned(skin, ownedSkinIDs, ownedVariantIDs, currentGun) {
  return (
    ownedSkinIDs.has(skin?.uuid) ||
    (skin?.levels || []).some((level) => ownedSkinIDs.has(level.uuid)) ||
    (skin?.chromas || []).some((chroma) => ownedVariantIDs.has(chroma.uuid)) ||
    currentGun?.SkinID === skin?.uuid
  );
}

function getSkinEquipDefaults(skin, ownedSkinIDs, ownedVariantIDs, currentGun) {
  const levels = Array.isArray(skin?.levels) ? skin.levels : [];
  const chromas = Array.isArray(skin?.chromas) ? skin.chromas : [];
  const ownedLevel = [...levels].reverse().find((level) => ownedSkinIDs.has(level.uuid));
  const defaultLevel = ownedLevel || levels[0] || {};
  const ownedChroma = chromas.find((chroma) => ownedVariantIDs.has(chroma.uuid));
  const defaultChroma = chromas.find((chroma) => chroma.uuid === skin?.uuid) || chromas[0] || {};

  return {
    skinID: skin?.uuid || "",
    skinLevelID: currentGun?.SkinID === skin?.uuid ? currentGun.SkinLevelID : defaultLevel.uuid || "",
    chromaID: currentGun?.SkinID === skin?.uuid ? currentGun.ChromaID : ownedChroma?.uuid || defaultChroma.uuid || ""
  };
}

async function fetchOwnedWeaponSkins(puuid, shard, weaponID) {
  if (useMocks) {
    return {
      weaponID,
      skins: []
    };
  }

  await ensureRiotReady(shard, "owned weapon skins");
  requireMatchingPUUID(puuid);

  const [loadout, weaponAssets, ownedSkinIDs, ownedVariantIDs] = await Promise.all([
    fetchRawPlayerLoadout(puuid, shard),
    fetchWeaponAssets(),
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.skins),
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.skinVariants)
  ]);
  const weapon = weaponAssets.weaponsByID.get(weaponID);
  const currentGun = (loadout.Guns || []).find((gun) => gun.ID === weaponID) || null;

  if (!weapon) {
    const error = new Error("Weapon was not found in Valorant-API assets.");
    error.statusCode = 404;
    error.code = "weapon_not_found";
    throw error;
  }

  const skins = (weapon.skins || [])
    .filter((skin) => skinIsOwned(skin, ownedSkinIDs, ownedVariantIDs, currentGun))
    .map((skin) => {
      const defaults = getSkinEquipDefaults(skin, ownedSkinIDs, ownedVariantIDs, currentGun);
      const level = (skin.levels || []).find((item) => item.uuid === defaults.skinLevelID) || (skin.levels || [])[0] || {};
      const chroma = (skin.chromas || []).find((item) => item.uuid === defaults.chromaID) || (skin.chromas || [])[0] || {};

      return {
        id: skin.uuid,
        weaponID,
        name: skin.displayName || weapon.displayName || skin.uuid,
        iconURL: firstURL(level.displayIcon, chroma.fullRender, chroma.displayIcon, skin.displayIcon, weapon.displayIcon),
        skinID: defaults.skinID,
        skinLevelID: defaults.skinLevelID,
        chromaID: defaults.chromaID,
        isEquipped: currentGun?.SkinID === skin.uuid
      };
    })
    .sort((a, b) => {
      if (a.isEquipped !== b.isEquipped) {
        return a.isEquipped ? -1 : 1;
      }

      return a.name.localeCompare(b.name);
    });

  return {
    weaponID,
    weaponName: weapon.displayName || weaponID,
    equippedSkinID: currentGun?.SkinID || "",
    skins
  };
}

async function fetchOwnedWeaponCharms(puuid, shard, weaponID) {
  if (useMocks) {
    return {
      weaponID,
      weaponName: weaponID,
      equippedCharmID: "",
      charms: []
    };
  }

  await ensureRiotReady(shard, "owned gun buddies");
  requireMatchingPUUID(puuid);

  const [loadout, weaponAssets, buddyAssets, ownedBuddyIDs] = await Promise.all([
    fetchRawPlayerLoadout(puuid, shard),
    fetchWeaponAssets(),
    fetchBuddyAssets(),
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.buddies)
  ]);
  const weapon = weaponAssets.weaponsByID.get(weaponID);
  const currentGun = (loadout.Guns || []).find((gun) => gun.ID === weaponID) || null;

  if (!weapon) {
    const error = new Error("Weapon was not found in Valorant-API assets.");
    error.statusCode = 404;
    error.code = "weapon_not_found";
    throw error;
  }

  const charms = Array.from(buddyAssets.buddiesByID.values())
    .filter((buddy) => {
      const levels = Array.isArray(buddy?.levels) ? buddy.levels : [];
      return (
        ownedBuddyIDs.has(buddy?.uuid) ||
        levels.some((level) => ownedBuddyIDs.has(level.uuid)) ||
        currentGun?.CharmID === buddy?.uuid
      );
    })
    .map((buddy) => {
      const levels = Array.isArray(buddy?.levels) ? buddy.levels : [];
      const ownedLevel = levels.find((level) => ownedBuddyIDs.has(level.uuid));
      const defaultLevel = ownedLevel || levels[0] || {};
      const isEquipped = currentGun?.CharmID === buddy.uuid;
      const equippedLevel = isEquipped
        ? levels.find((level) => level.uuid === currentGun?.CharmLevelID) || defaultLevel
        : defaultLevel;

      return {
        id: buddy.uuid,
        weaponID,
        name: buddy.displayName || buddy.uuid,
        iconURL: firstURL(equippedLevel.displayIcon, buddy.displayIcon),
        charmID: buddy.uuid,
        charmLevelID: equippedLevel.uuid || "",
        isEquipped
      };
    })
    .sort((a, b) => {
      if (a.isEquipped !== b.isEquipped) {
        return a.isEquipped ? -1 : 1;
      }

      return a.name.localeCompare(b.name);
    });

  return {
    weaponID,
    weaponName: weapon.displayName || weaponID,
    equippedCharmID: currentGun?.CharmID || "",
    charms
  };
}

async function fetchOwnedItemsDebug(puuid, shard) {
  await ensureRiotReady(shard, "owned items debug");
  requireMatchingPUUID(puuid);

  const [weaponAssets, ownedSkinIDs, ownedVariantIDs] = await Promise.all([
    fetchWeaponAssets(),
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.skins),
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.skinVariants)
  ]);

  return {
    skinCount: ownedSkinIDs.size,
    variantCount: ownedVariantIDs.size,
    skinIDs: Array.from(ownedSkinIDs).sort(),
    variantIDs: Array.from(ownedVariantIDs).sort(),
    ownedWeaponSkins: Array.from(weaponAssets.weaponsByID.values()).map((weapon) => ({
      weaponID: weapon.uuid,
      weaponName: weapon.displayName || weapon.uuid,
      skins: (weapon.skins || [])
        .filter((skin) => skinIsOwned(skin, ownedSkinIDs, ownedVariantIDs, null))
        .map((skin) => ({
          name: skin.displayName || skin.uuid,
          skinID: skin.uuid,
          levelIDs: (skin.levels || []).map((level) => level.uuid),
          chromaIDs: (skin.chromas || []).map((chroma) => chroma.uuid)
        }))
    })).filter((weapon) => weapon.skins.length > 0)
  };
}

async function fetchCollections(puuid, shard) {
  if (useMocks) {
    return {
      sprays: [],
      playerCards: []
    };
  }

  await ensureRiotReady(shard, "collections");
  requireMatchingPUUID(puuid);

  const [ownedSprayIDs, ownedCardIDs, sprayAssets, cardAssets] = await Promise.all([
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.sprays),
    fetchOwnedItemIDs(puuid, shard, itemTypeIDs.cards),
    fetchSprayAssets(),
    fetchPlayerCardAssets()
  ]);

  const sprays = Array.from(ownedSprayIDs)
    .map((id) => {
      const spray = sprayAssets.spraysByID.get(id) || {};
      return {
        id,
        name: spray.displayName || id,
        iconURL: firstURL(spray.fullTransparentIcon, spray.displayIcon, spray.fullIcon)
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));

  const playerCards = Array.from(ownedCardIDs)
    .map((id) => {
      const card = cardAssets.cardsByID.get(id) || {};
      return {
        id,
        name: card.displayName || id,
        iconURL: firstURL(card.smallArt, card.wideArt, card.largeArt)
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));

  return {
    sprays,
    playerCards
  };
}

async function equipWeaponSkin(puuid, shard, body) {
  if (useMocks) {
    return getMockLoadout(puuid);
  }

  await ensureRiotReady(shard, "set player loadout");
  requireMatchingPUUID(puuid);

  const weaponID = body.weaponID || body.id;
  const skinID = body.skinID;
  const skinLevelID = body.skinLevelID;
  const chromaID = body.chromaID;

  if (!weaponID || !skinID || !skinLevelID || !chromaID) {
    const error = new Error("weaponID, skinID, skinLevelID, and chromaID are required.");
    error.statusCode = 400;
    error.code = "missing_loadout_fields";
    throw error;
  }

  const loadout = await fetchRawPlayerLoadout(puuid, shard);
  const gun = (loadout.Guns || []).find((item) => item.ID === weaponID);

  if (!gun) {
    const error = new Error("Weapon was not found in current loadout.");
    error.statusCode = 404;
    error.code = "loadout_weapon_not_found";
    throw error;
  }

  const nextLoadout = {
    Guns: (loadout.Guns || []).map((item) => {
      if (item.ID !== weaponID) {
        return item;
      }

      return {
        ...item,
        SkinID: skinID,
        SkinLevelID: skinLevelID,
        ChromaID: chromaID,
        Attachments: item.Attachments || []
      };
    }),
    Sprays: loadout.Sprays || [],
    Identity: loadout.Identity || {},
    Incognito: Boolean(loadout.Incognito)
  };

  await fetchRiotJSON(`https://pd.${shard}.a.pvp.net/personalization/v2/players/${encodeURIComponent(puuid)}/playerloadout`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(nextLoadout),
    errorMessage: "Riot set player loadout request failed.",
    errorCode: "riot_set_loadout_failed"
  });

  return fetchPlayerLoadout(puuid, shard);
}

async function equipWeaponCharm(puuid, shard, body) {
  if (useMocks) {
    return getMockLoadout(puuid);
  }

  await ensureRiotReady(shard, "set player loadout");
  requireMatchingPUUID(puuid);

  const weaponID = body.weaponID || body.id;
  const charmID = body.charmID;
  const charmLevelID = body.charmLevelID;

  if (!weaponID || !charmID || !charmLevelID) {
    const error = new Error("weaponID, charmID, and charmLevelID are required.");
    error.statusCode = 400;
    error.code = "missing_loadout_charm_fields";
    throw error;
  }

  const loadout = await fetchRawPlayerLoadout(puuid, shard);
  const gun = (loadout.Guns || []).find((item) => item.ID === weaponID);

  if (!gun) {
    const error = new Error("Weapon was not found in current loadout.");
    error.statusCode = 404;
    error.code = "loadout_weapon_not_found";
    throw error;
  }

  const nextLoadout = {
    Guns: (loadout.Guns || []).map((item) => {
      if (item.ID !== weaponID) {
        return item;
      }

      return {
        ...item,
        CharmID: charmID,
        CharmLevelID: charmLevelID,
        Attachments: item.Attachments || []
      };
    }),
    Sprays: loadout.Sprays || [],
    Identity: loadout.Identity || {},
    Incognito: Boolean(loadout.Incognito)
  };

  await fetchRiotJSON(`https://pd.${shard}.a.pvp.net/personalization/v2/players/${encodeURIComponent(puuid)}/playerloadout`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(nextLoadout),
    errorMessage: "Riot set player loadout request failed.",
    errorCode: "riot_set_loadout_failed"
  });

  return fetchPlayerLoadout(puuid, shard);
}

async function enrichFriendsWithMMR(friends, shard) {
  const results = [];
  const concurrency = 4;

  for (let index = 0; index < friends.length; index += concurrency) {
    const batch = friends.slice(index, index + concurrency);
    const enrichedBatch = await Promise.all(batch.map(async (friend) => {
      if (!friend.puuid) {
        return friend;
      }

      try {
        return {
          ...friend,
          mmr: await fetchPlayerMMR(friend.puuid, shard)
        };
      } catch (error) {
        return {
          ...friend,
          mmrError: error.code || error.message,
          mmrErrorStatus: error.statusCode || null,
          mmrErrorDetails: error.body || null
        };
      }
    }));

    results.push(...enrichedBatch);

    if (index + concurrency < friends.length) {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }

  return results;
}

async function fetchFriendsMMR(puuids, shard) {
  const uniquePUUIDs = [...new Set(puuids.map((puuid) => puuid.trim()).filter(Boolean))];
  const friends = uniquePUUIDs.map((puuid) => ({
    puuid,
    gameName: "",
    tagLine: ""
  }));
  const enrichedFriends = await enrichFriendsWithMMR(friends, shard);

  return {
    friends: enrichedFriends
  };
}

function normalizeCompetitiveUpdate(update) {
  return {
    matchID: update.MatchID || null,
    matchStartTime: update.MatchStartTime || null,
    rrChange: update.RankedRatingEarned ?? null,
    rrPerformanceBonus: update.RankedRatingPerformanceBonus ?? 0,
    afkPenalty: update.AFKPenalty ?? 0,
    rankedRatingBefore: update.RankedRatingBeforeUpdate ?? null,
    rankedRatingAfter: update.RankedRatingAfterUpdate ?? null,
    tierBefore: update.TierBeforeUpdate ?? null,
    tierAfter: update.TierAfterUpdate ?? null,
    seasonID: update.SeasonID || null,
    mapID: update.MapID || null
  };
}

function getActRankWins(season) {
  const winsByTier = season?.WinsByTier || {};

  return Object.entries(winsByTier)
    .map(([tier, wins]) => ({
      tier: Number(tier),
      wins: Number(wins) || 0
    }))
    .filter((entry) => entry.tier > 0 && entry.wins > 0)
    .sort((a, b) => b.tier - a.tier);
}

function getActRankBadgeCells(season, maxCells = 225) {
  const cells = [];

  for (const entry of getActRankWins(season)) {
    for (let index = 0; index < entry.wins && cells.length < maxCells; index += 1) {
      cells.push({
        tier: entry.tier
      });
    }

    if (cells.length >= maxCells) {
      break;
    }
  }

  return cells;
}

function getCompetitiveActs(seasons, currentSeasonID) {
  return Object.entries(seasons)
    .map(([seasonID, season]) => ({
      seasonID,
      name: "",
      type: "",
      startTime: "",
      endTime: "",
      isCurrent: seasonID === currentSeasonID,
      competitiveTier: season.CompetitiveTier || 0,
      rankedRating: season.RankedRating || 0,
      leaderboardRank: season.LeaderboardRank || 0,
      numberOfWins: season.NumberOfWins || 0,
      winsByTier: getActRankWins(season),
      badgeCells: getActRankBadgeCells(season)
    }))
    .filter((act) => act.numberOfWins > 0 || act.winsByTier.length > 0)
    .sort((a, b) => {
      if (a.isCurrent !== b.isCurrent) {
        return a.isCurrent ? -1 : 1;
      }

      return a.seasonID.localeCompare(b.seasonID);
    });
}

function getLatestCompetitiveInfo(mmr, recentCompetitiveUpdates = [], recentCompetitiveUpdatesError = null) {
  const competitive = mmr?.QueueSkills?.competitive;
  const seasons = competitive?.SeasonalInfoBySeasonID || {};
  const latestUpdate = mmr?.LatestCompetitiveUpdate || {};
  const latestSeasonID = latestUpdate.SeasonID;
  const latestSeason = latestSeasonID ? seasons[latestSeasonID] : null;
  const season = latestSeason || Object.values(seasons).at(-1) || {};
  const lastMatchRRChanges = recentCompetitiveUpdates.length > 0
    ? recentCompetitiveUpdates.map(normalizeCompetitiveUpdate)
    : (latestUpdate.MatchID ? [normalizeCompetitiveUpdate(latestUpdate)] : []);
  const latestRRChange = lastMatchRRChanges[0] || null;

  return {
    subject: mmr?.Subject,
    competitiveTier: latestUpdate.TierAfterUpdate ?? season.CompetitiveTier ?? 0,
    rankedRating: latestUpdate.RankedRatingAfterUpdate ?? season.RankedRating ?? 0,
    leaderboardRank: season.LeaderboardRank || 0,
    numberOfWins: season.NumberOfWins || 0,
    seasonID: latestSeasonID || season.SeasonID || "",
    hasRank: Boolean(latestUpdate.TierAfterUpdate || season.CompetitiveTier),
    lastMatchID: latestRRChange?.matchID || null,
    lastMatchStartTime: latestRRChange?.matchStartTime || null,
    lastMatchRRChange: latestRRChange?.rrChange ?? null,
    lastMatchRRPerformanceBonus: latestRRChange?.rrPerformanceBonus ?? 0,
    lastMatchAFKPenalty: latestRRChange?.afkPenalty ?? 0,
    lastMatchRankedRatingBefore: latestRRChange?.rankedRatingBefore ?? null,
    lastMatchRankedRatingAfter: latestRRChange?.rankedRatingAfter ?? null,
    lastMatchTierBefore: latestRRChange?.tierBefore ?? null,
    lastMatchTierAfter: latestRRChange?.tierAfter ?? null,
    lastMatchRRChanges,
    lastMatchRRChangesError: recentCompetitiveUpdatesError,
    actRankWins: getActRankWins(season),
    actRankBadgeCells: getActRankBadgeCells(season),
    actRankBadgeHidden: Boolean(mmr?.IsActRankBadgeHidden),
    acts: getCompetitiveActs(seasons, latestSeasonID || season.SeasonID || "")
  };
}

async function fetchCompetitiveUpdates(puuid, shard, limit = 5) {
  const endIndex = Math.max(1, Math.min(limit, 20));
  const url = new URL(`https://pd.${shard}.a.pvp.net/mmr/v1/players/${encodeURIComponent(puuid)}/competitiveupdates`);
  url.searchParams.set("startIndex", "0");
  url.searchParams.set("endIndex", String(endIndex));
  url.searchParams.set("queue", "competitive");

  const body = await fetchRiotJSON(url.toString(), {
    errorMessage: "Riot competitive updates request failed.",
    errorCode: "riot_competitive_updates_failed"
  });

  return Array.isArray(body?.Matches) ? body.Matches.slice(0, limit) : [];
}

async function fetchPlayerMMR(puuid, shard) {
  if (useMocks) {
    return {
      subject: puuid,
      competitiveTier: 15,
      rankedRating: 50,
      leaderboardRank: 0,
      numberOfWins: 12,
      seasonID: "mock-season",
      hasRank: true,
      rankName: "Platinum 1",
      rankIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/15/largeicon.png",
      actRankWins: [
        { tier: 15, wins: 18 },
        { tier: 14, wins: 12 },
        { tier: 13, wins: 6 }
      ],
      actRankBadgeCells: [
        ...Array.from({ length: 18 }, () => ({
          tier: 15,
          rankTriangleDownIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/15/ranktriangledownicon.png",
          rankTriangleUpIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/15/ranktriangleupicon.png"
        })),
        ...Array.from({ length: 12 }, () => ({
          tier: 14,
          rankTriangleDownIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/14/ranktriangledownicon.png",
          rankTriangleUpIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/14/ranktriangleupicon.png"
        })),
        ...Array.from({ length: 6 }, () => ({
          tier: 13,
          rankTriangleDownIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/13/ranktriangledownicon.png",
          rankTriangleUpIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/13/ranktriangleupicon.png"
        }))
      ],
      actRankBadgeHidden: false,
      acts: [
        {
          seasonID: "mock-season",
          name: "Current Act",
          type: "act",
          startTime: "",
          endTime: "",
          isCurrent: true,
          competitiveTier: 15,
          rankedRating: 50,
          leaderboardRank: 0,
          numberOfWins: 36,
          winsByTier: [
            { tier: 15, wins: 18 },
            { tier: 14, wins: 12 },
            { tier: 13, wins: 6 }
          ],
          badgeCells: [
            ...Array.from({ length: 18 }, () => ({
              tier: 15,
              rankTriangleDownIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/15/ranktriangledownicon.png",
              rankTriangleUpIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/15/ranktriangleupicon.png"
            })),
            ...Array.from({ length: 12 }, () => ({
              tier: 14,
              rankTriangleDownIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/14/ranktriangledownicon.png",
              rankTriangleUpIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/14/ranktriangleupicon.png"
            })),
            ...Array.from({ length: 6 }, () => ({
              tier: 13,
              rankTriangleDownIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/13/ranktriangledownicon.png",
              rankTriangleUpIconURL: "https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/13/ranktriangleupicon.png"
            }))
          ]
        }
      ],
      lastMatchRRChanges: [
        { matchID: "mock-match-1", matchStartTime: Date.now() - 3600000, rrChange: 18, rrPerformanceBonus: 3, afkPenalty: 0, rankedRatingBefore: 32, rankedRatingAfter: 50, tierBefore: 15, tierAfter: 15, seasonID: "mock-season", mapID: "mock-map-1" },
        { matchID: "mock-match-2", matchStartTime: Date.now() - 7200000, rrChange: -12, rrPerformanceBonus: 0, afkPenalty: 0, rankedRatingBefore: 44, rankedRatingAfter: 32, tierBefore: 15, tierAfter: 15, seasonID: "mock-season", mapID: "mock-map-2" },
        { matchID: "mock-match-3", matchStartTime: Date.now() - 10800000, rrChange: 22, rrPerformanceBonus: 5, afkPenalty: 0, rankedRatingBefore: 22, rankedRatingAfter: 44, tierBefore: 15, tierAfter: 15, seasonID: "mock-season", mapID: "mock-map-3" },
        { matchID: "mock-match-4", matchStartTime: Date.now() - 14400000, rrChange: 0, rrPerformanceBonus: 0, afkPenalty: 0, rankedRatingBefore: 22, rankedRatingAfter: 22, tierBefore: 15, tierAfter: 15, seasonID: "mock-season", mapID: "mock-map-4" },
        { matchID: "mock-match-5", matchStartTime: Date.now() - 18000000, rrChange: -8, rrPerformanceBonus: 0, afkPenalty: 0, rankedRatingBefore: 30, rankedRatingAfter: 22, tierBefore: 15, tierAfter: 15, seasonID: "mock-season", mapID: "mock-map-5" }
      ],
      lastMatchRRChangesError: null
    };
  }

  await refreshAuthState();

  if (!shard) {
    const error = new Error("Set VALORANT_SHARD or pass ?shard=na to use player MMR.");
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

  const [mmr, competitiveUpdatesResult] = await Promise.all([
    fetchRiotJSON(`https://pd.${shard}.a.pvp.net/mmr/v1/players/${encodeURIComponent(puuid)}`, {
      errorMessage: "Riot player MMR request failed.",
      errorCode: "riot_player_mmr_failed"
    }),
    fetchCompetitiveUpdates(puuid, shard, 5)
      .then((updates) => ({ updates, error: null }))
      .catch((error) => ({
        updates: [],
        error: error.body?.message || error.message || "Competitive updates unavailable."
      }))
  ]);

  return withCompetitiveTierAssets(
    getLatestCompetitiveInfo(mmr, competitiveUpdatesResult.updates, competitiveUpdatesResult.error)
  );
}

async function fetchFirstFriendMMR(shard) {
  const friends = await fetchFriends();
  const friend = friends.friends[0];

  if (!friend) {
    const error = new Error("No friends found to test MMR.");
    error.statusCode = 404;
    error.code = "no_friends_found";
    throw error;
  }

  const mmr = await fetchPlayerMMR(friend.puuid, shard);

  return {
    friend,
    mmr
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

  if (req.method === "OPTIONS") {
    sendJSON(res, 200, { ok: true });
    return;
  }

  if (!["GET", "PUT"].includes(req.method)) {
    sendJSON(res, 405, {
      error: "method_not_allowed",
      message: "Only GET and PUT requests are supported right now."
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

  if (req.method === "GET" && pathParts[0] === "loadout" && pathParts[1] && pathParts[2] === "skins" && pathParts[3]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const skins = await fetchOwnedWeaponSkins(pathParts[1], shard, pathParts[3]);
      sendJSON(res, 200, skins);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "owned_weapon_skins_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (req.method === "GET" && pathParts[0] === "loadout" && pathParts[1] && pathParts[2] === "charms" && pathParts[3]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const charms = await fetchOwnedWeaponCharms(pathParts[1], shard, pathParts[3]);
      sendJSON(res, 200, charms);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "owned_weapon_charms_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (req.method === "GET" && pathParts[0] === "loadout" && pathParts[1] && pathParts[2] === "owned-debug") {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const ownedItems = await fetchOwnedItemsDebug(pathParts[1], shard);
      sendJSON(res, 200, ownedItems);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "owned_items_debug_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (req.method === "PUT" && pathParts[0] === "loadout" && pathParts[1] && pathParts[2] === "equip") {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const body = await readJSONBody(req);
      const loadout = await equipWeaponSkin(pathParts[1], shard, body);
      sendJSON(res, 200, loadout);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "equip_weapon_skin_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (req.method === "PUT" && pathParts[0] === "loadout" && pathParts[1] && pathParts[2] === "equip-charm") {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const body = await readJSONBody(req);
      const loadout = await equipWeaponCharm(pathParts[1], shard, body);
      sendJSON(res, 200, loadout);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "equip_weapon_charm_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (req.method === "GET" && pathParts[0] === "loadout" && pathParts[1]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const loadout = await fetchPlayerLoadout(pathParts[1], shard);
      sendJSON(res, 200, loadout);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "loadout_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (req.method === "GET" && pathParts[0] === "collections" && pathParts[1]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const collections = await fetchCollections(pathParts[1], shard);
      sendJSON(res, 200, collections);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "collections_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (requestURL.pathname === "/friends/first-mmr") {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const result = await fetchFirstFriendMMR(shard);
      sendJSON(res, 200, result);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "friend_mmr_error",
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

  if (requestURL.pathname === "/friends/mmr") {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const puuids = (requestURL.searchParams.get("puuids") || "").split(",");
      const result = await fetchFriendsMMR(puuids, shard);
      sendJSON(res, 200, result);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "friends_mmr_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (requestURL.pathname === "/friends/status") {
    try {
      const puuids = (requestURL.searchParams.get("puuids") || "").split(",");
      const result = await fetchFriendsStatus(puuids);
      sendJSON(res, 200, result);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "friends_status_error",
        message: error.message,
        details: error.body
      });
    }
    return;
  }

  if (pathParts[0] === "mmr" && pathParts[1]) {
    try {
      const shard = requestURL.searchParams.get("shard") || valorantShard;
      const result = await fetchPlayerMMR(pathParts[1], shard);
      sendJSON(res, 200, result);
    } catch (error) {
      sendJSON(res, error.statusCode || 500, {
        error: error.code || "mmr_error",
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
      "GET /loadout/:puuid",
      "GET /loadout/:puuid/skins/:weaponID",
      "GET /loadout/:puuid/charms/:weaponID",
      "PUT /loadout/:puuid/equip",
      "PUT /loadout/:puuid/equip-charm",
      "GET /collections/:puuid",
      "GET /friends",
      "GET /friends/mmr?puuids=:puuid,:puuid",
      "GET /friends/status?puuids=:puuid,:puuid",
      "GET /friends/first-mmr",
      "GET /mmr/:puuid",
      "GET /parties/:partyID/queues"
    ]
  });
});

server.listen(port, host, () => {
  console.log(`RR Bridge running at http://${host}:${port}`);
});
