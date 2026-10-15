import { describe, expect, it } from "vitest";
import { parseAppIdentity } from "../../src/config.js";
import { appleAppSiteAssociation, assetLinks } from "../../src/wellKnown.js";
import { FULL_APP_JSON, testApp } from "../support/app.js";

const FP = FULL_APP_JSON.android.sha256CertFingerprints[0];

describe("association files", () => {
  it("apple-app-site-association has the exact shape", () => {
    expect(appleAppSiteAssociation(parseAppIdentity(FULL_APP_JSON))).toStrictEqual({
      applinks: {
        details: [
          {
            appIDs: ["ABCDE12345.com.example.groupphotos"],
            components: [
              { "/": "/i/*/*", exclude: true, comment: "Invite page sub-resources (images, preview JSON) stay on the web" },
              { "/": "/i/*", comment: "Invite links" },
            ],
          },
        ],
      },
      appclips: { apps: ["ABCDE12345.com.example.groupphotos.Clip"] },
    });
  });

  it("apple-app-site-association is empty while the Team ID is BLOCKED", () => {
    const app = parseAppIdentity({ ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, teamId: null } });
    expect(appleAppSiteAssociation(app)).toStrictEqual({ applinks: { details: [] }, appclips: { apps: [] } });
  });

  it("assetlinks.json has the exact shape", () => {
    expect(assetLinks(parseAppIdentity(FULL_APP_JSON))).toStrictEqual([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: { namespace: "android_app", package_name: "com.example.groupphotos", sha256_cert_fingerprints: [FP] },
      },
    ]);
    expect(assetLinks(parseAppIdentity({ ...FULL_APP_JSON, android: { ...FULL_APP_JSON.android, sha256CertFingerprints: [] } }))).toStrictEqual([]);
  });

  it.each(["/.well-known/apple-app-site-association", "/.well-known/assetlinks.json"])("%s is served as JSON without a redirect", async (path) => {
    const { app } = testApp(null);
    const res = await app.request(path);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("application/json");
    expect(res.headers.get("location")).toBeNull();
    const body = await res.json();
    if (path.endsWith("association")) expect(body).toStrictEqual(appleAppSiteAssociation(parseAppIdentity(FULL_APP_JSON)));
    else expect(body).toStrictEqual(assetLinks(parseAppIdentity(FULL_APP_JSON)));
  });
});
