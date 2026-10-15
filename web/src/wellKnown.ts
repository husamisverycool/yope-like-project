// Association files, generated once at startup from config/app.json
// (design/tokens/invite.json invite.appclip.layout.association; Partiful's own files have the
// same shape: https://partiful.com/.well-known/apple-app-site-association, …/assetlinks.json).

import { appClipBundleId, type AppIdentity } from "./config.js";

export function appleAppSiteAssociation(app: AppIdentity): object {
  const team = app.ios.teamId;
  return {
    applinks: {
      details: team
        ? [
            {
              appIDs: [`${team}.${app.ios.bundleId}`],
              components: [
                { "/": "/i/*/*", exclude: true, comment: "Invite page sub-resources (images, preview JSON) stay on the web" },
                { "/": "/i/*", comment: "Invite links" },
              ],
            },
          ]
        : [],
    },
    appclips: { apps: team ? [`${team}.${appClipBundleId(app)}`] : [] },
  };
}

export function assetLinks(app: AppIdentity): object[] {
  if (app.android.sha256CertFingerprints.length === 0) return [];
  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: app.android.applicationId,
        sha256_cert_fingerprints: app.android.sha256CertFingerprints,
      },
    },
  ];
}
