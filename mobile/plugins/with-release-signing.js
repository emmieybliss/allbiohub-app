/**
 * Signs `assembleRelease` / `bundleRelease` with the AllBioHub release key,
 * so the Expo app installs as an update over the Flutter app (same package,
 * same key). The key never enters the repository: the build reads it from
 * environment variables that the GitHub Release workflow fills from secrets.
 *
 *   ALLBIOHUB_UPLOAD_STORE_FILE      absolute path to the .jks file
 *   ALLBIOHUB_UPLOAD_STORE_PASSWORD
 *   ALLBIOHUB_UPLOAD_KEY_ALIAS       (default "allbiohub")
 *   ALLBIOHUB_UPLOAD_KEY_PASSWORD    (default: the store password)
 *
 * Without them, release builds keep Expo's default (debug key), which is
 * fine for test builds. EAS Build ignores this and uses its own credentials.
 */
const { withAppBuildGradle } = require('expo/config-plugins');

const MARKER = '// allbiohub-release-signing';

const SIGNING_BLOCK = `
        release {
            ${MARKER}
            if (System.getenv("ALLBIOHUB_UPLOAD_STORE_FILE")) {
                storeFile file(System.getenv("ALLBIOHUB_UPLOAD_STORE_FILE"))
                storePassword System.getenv("ALLBIOHUB_UPLOAD_STORE_PASSWORD")
                keyAlias System.getenv("ALLBIOHUB_UPLOAD_KEY_ALIAS") ?: "allbiohub"
                keyPassword System.getenv("ALLBIOHUB_UPLOAD_KEY_PASSWORD") ?: System.getenv("ALLBIOHUB_UPLOAD_STORE_PASSWORD")
            }
        }`;

function addReleaseSigning(gradle) {
  if (gradle.includes(MARKER)) return gradle;
  // 1. Add a release signing config next to the generated debug one.
  const withConfig = gradle.replace(/signingConfigs\s*\{/, (m) => `${m}${SIGNING_BLOCK}`);
  if (withConfig === gradle) {
    throw new Error('with-release-signing: signingConfigs block not found in app/build.gradle');
  }
  // 2. Use it for release builds when the key is present.
  const releaseType = /(buildTypes\s*\{[\s\S]*?release\s*\{[\s\S]*?)signingConfig\s+signingConfigs\.debug/;
  const result = withConfig.replace(
    releaseType,
    (_m, head) =>
      `${head}signingConfig System.getenv("ALLBIOHUB_UPLOAD_STORE_FILE") ? signingConfigs.release : signingConfigs.debug`,
  );
  if (result === withConfig) {
    throw new Error('with-release-signing: release buildType signingConfig not found in app/build.gradle');
  }
  return result;
}

module.exports = function withReleaseSigning(config) {
  return withAppBuildGradle(config, (mod) => {
    if (mod.modResults.language !== 'groovy') {
      throw new Error('with-release-signing: expected a Groovy app/build.gradle');
    }
    mod.modResults.contents = addReleaseSigning(mod.modResults.contents);
    return mod;
  });
};

module.exports.addReleaseSigning = addReleaseSigning;
