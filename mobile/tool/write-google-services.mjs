#!/usr/bin/env node
// Writes google-services.json (the Firebase Android client file) from the
// FIREBASE_* values that the Flutter build used, so the same Actions secrets
// keep working. Exits quietly when they are missing: the app then builds with
// push notifications off.
//
//   node tool/write-google-services.mjs [out=./google-services.json]
import fs from 'node:fs';

const out = process.argv[2] ?? './google-services.json';
const { FIREBASE_PROJECT_ID: projectId, FIREBASE_API_KEY: apiKey, FIREBASE_APP_ID: appId, FIREBASE_MESSAGING_SENDER_ID: senderId } =
  process.env;
const bucket = process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`;
const pkg = 'com.allbiohub.app';

if (!projectId || !apiKey || !appId || !senderId) {
  console.log('No Firebase secrets: this build has push notifications off.');
  process.exit(0);
}

const file = {
  project_info: { project_number: senderId, project_id: projectId, storage_bucket: bucket },
  client: [
    {
      client_info: { mobilesdk_app_id: appId, android_client_info: { package_name: pkg } },
      oauth_client: [],
      api_key: [{ current_key: apiKey }],
      services: { appinvite_service: { other_platform_oauth_client: [] } },
    },
  ],
  configuration_version: '1',
};
fs.writeFileSync(out, JSON.stringify(file, null, 2));
console.log(`Firebase settings found: wrote ${out}, push notifications are on.`);
