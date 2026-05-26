const fs = require("fs");
const https = require("https");
const path = require("path");

function readLockfile(lockfilePath) {
  const lockfile = fs.readFileSync(lockfilePath, "utf8").trim();
  const parts = lockfile.split(":");

  if (parts.length < 5) {
    throw new Error("Riot Client lockfile did not have the expected format.");
  }

  return {
    port: parts[2],
    password: parts[3],
    protocol: parts[4]
  };
}

function requestRaw(url, options = {}) {
  return new Promise((resolve, reject) => {
    const requestBody = options.body || "";
    const request = https.request(url, {
      method: options.method || "GET",
      headers: options.headers || {},
      rejectUnauthorized: false
    }, (response) => {
      let body = "";

      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        body += chunk;
      });
      response.on("end", () => {
        resolve({
          statusCode: response.statusCode,
          headers: response.headers,
          body
        });
      });
    });

    if (requestBody) {
      request.write(requestBody);
    }

    request.on("error", reject);
    request.end();
  });
}

async function requestJSON(url, options = {}) {
  const response = await requestRaw(url, options);
  let parsed;

  try {
    parsed = response.body ? JSON.parse(response.body) : {};
  } catch {
    throw new Error(`Riot endpoint returned non-JSON: ${response.body}`);
  }

  if (response.statusCode < 200 || response.statusCode > 299) {
    throw new Error(`Riot endpoint returned HTTP ${response.statusCode}: ${response.body}`);
  }

  return parsed;
}

function getAccessToken(response) {
  return response.accessToken || response.access_token || response.token;
}

function getEntitlementsToken(response) {
  return response.entitlementsToken || response.entitlements_token || response.token;
}

function parseAccessTokenRedirect(redirectURL) {
  const hash = new URL(redirectURL).hash.slice(1);
  const params = new URLSearchParams(hash);
  const accessToken = params.get("access_token");
  const idToken = params.get("id_token");

  if (!accessToken) {
    throw new Error("Access token missing from Riot redirect.");
  }

  const tokenParts = accessToken.split(".");
  if (tokenParts.length !== 3) {
    throw new Error(`Invalid access token, expected 3 parts, got ${tokenParts.length}.`);
  }

  const tokenData = JSON.parse(Buffer.from(tokenParts[1], "base64").toString("utf8"));

  return {
    accessToken,
    idToken,
    subject: tokenData.sub
  };
}

function decodeJWTPayload(token) {
  if (!token) {
    return {};
  }

  const parts = token.split(".");
  if (parts.length !== 3) {
    return {};
  }

  try {
    return JSON.parse(Buffer.from(parts[1], "base64").toString("utf8"));
  } catch {
    return {};
  }
}

function readRiotSSID() {
  const settingsPath = path.join(
    process.env.LOCALAPPDATA || "",
    "Riot Games",
    "Riot Client",
    "Data",
    "RiotGamesPrivateSettings.yaml"
  );
  const settings = fs.readFileSync(settingsPath, "utf8");
  const match = /name: "ssid".*?value: "(.+?)"/s.exec(settings);

  if (!match) {
    throw new Error(`Could not find ssid in ${settingsPath}.`);
  }

  const ssid = match[1];

  if (ssid.split(".").length !== 3) {
    throw new Error("Invalid ssid in RiotGamesPrivateSettings.yaml.");
  }

  return ssid;
}

function readClientVersionFromLog() {
  const logPath = path.join(
    process.env.LOCALAPPDATA || "",
    "VALORANT",
    "Saved",
    "Logs",
    "ShooterGame.log"
  );

  if (!fs.existsSync(logPath)) {
    return "";
  }

  const log = fs.readFileSync(logPath, "utf8");
  const matches = [
    ...log.matchAll(/release-[\w.-]+-shipping-[\w.-]+/gi),
    ...log.matchAll(/riotClientVersion["=: ]+([^\s"',]+)/gi)
  ];

  if (matches.length === 0) {
    return "";
  }

  const lastMatch = matches[matches.length - 1];
  return lastMatch[1] || lastMatch[0];
}

async function getLatestClientVersion() {
  try {
    const response = await requestJSON("https://valorant-api.com/v1/version");
    return response?.data?.riotClientVersion || "";
  } catch {
    return "";
  }
}

async function getAccessTokenFromSSID() {
  const ssid = readRiotSSID();
  const response = await requestRaw("https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in&client_id=play-valorant-web-prod&response_type=token%20id_token&nonce=1&scope=account%20openid", {
    headers: {
      Cookie: `ssid=${ssid}`,
      "User-Agent": ""
    }
  });
  const location = response.headers.location;

  if (!location) {
    throw new Error(`Riot reauth did not return a location header. HTTP ${response.statusCode}: ${response.body}`);
  }

  if (!location.startsWith("https://playvalorant.com/opt_in")) {
    throw new Error(`Riot reauth returned an unexpected location: ${location.slice(0, 80)}`);
  }

  return parseAccessTokenRedirect(location);
}

async function getRemoteEntitlement(accessToken) {
  return requestJSON("https://entitlements.auth.riotgames.com/api/token/v1", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      "Content-Length": "2",
      "User-Agent": ""
    },
    body: "{}"
  });
}

async function main() {
  const lockfilePath = process.argv[2];

  if (!lockfilePath) {
    throw new Error("Usage: node riot-auth.js <lockfile-path>");
  }

  const lockfile = readLockfile(lockfilePath);
  const credentials = Buffer.from(`riot:${lockfile.password}`, "ascii").toString("base64");
  const localHeaders = {
    Authorization: `Basic ${credentials}`
  };
  let tokenResponse;

  try {
    tokenResponse = await requestJSON(`https://127.0.0.1:${lockfile.port}/entitlements/v1/token`, {
      headers: localHeaders
    });
  } catch (error) {
    const errors = [error];
    let accessInfo;

    try {
      const accessResponse = await requestJSON(`https://127.0.0.1:${lockfile.port}/rso-auth/v1/authorization/access-token`, {
        headers: localHeaders
      });
      accessInfo = {
        accessToken: getAccessToken(accessResponse),
        subject: accessResponse.subject
      };
    } catch (accessError) {
      errors.push(accessError);
      accessInfo = await getAccessTokenFromSSID();
    }

    if (!accessInfo.accessToken) {
      throw new Error("Could not get Riot access token.");
    }

    const entitlementResponse = await getRemoteEntitlement(accessInfo.accessToken);

    tokenResponse = {
      accessToken: accessInfo.accessToken,
      idToken: accessInfo.idToken,
      entitlementsToken: getEntitlementsToken(entitlementResponse),
      subject: entitlementResponse.subject || accessInfo.subject,
      warnings: errors.map((item) => item.message)
    };
  }

  const idTokenData = decodeJWTPayload(tokenResponse.idToken);
  const account = idTokenData.acct || {};

  process.stdout.write(JSON.stringify({
    accessToken: getAccessToken(tokenResponse),
    entitlementsToken: getEntitlementsToken(tokenResponse),
    subject: tokenResponse.subject,
    gameName: account.game_name,
    tagLine: account.tag_line,
    clientVersion: readClientVersionFromLog() || await getLatestClientVersion()
  }));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
