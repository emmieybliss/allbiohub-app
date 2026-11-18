// eslint-disable-next-line @typescript-eslint/no-require-imports
const { addReleaseSigning } = require('../../plugins/with-release-signing');

const template = `
android {
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
        }
    }
    buildTypes {
        debug {
            signingConfig signingConfigs.debug
        }
        release {
            // Caution! In production, you need to generate your own keystore file.
            signingConfig signingConfigs.debug
            minifyEnabled enableMinifyInReleaseBuilds
        }
    }
}`;

it('signs release builds with the AllBioHub key when it is provided', () => {
  const out: string = addReleaseSigning(template);
  expect(out).toContain('storeFile file(System.getenv("ALLBIOHUB_UPLOAD_STORE_FILE"))');
  expect(out).toContain('signingConfig System.getenv("ALLBIOHUB_UPLOAD_STORE_FILE") ? signingConfigs.release : signingConfigs.debug');
  // Debug builds keep the debug key.
  expect(out.match(/signingConfig signingConfigs\.debug/g)).toHaveLength(1);
  // Running twice changes nothing.
  expect(addReleaseSigning(out)).toBe(out);
});

it('fails loudly if the Gradle template changes', () => {
  expect(() => addReleaseSigning('android {}')).toThrow(/signingConfigs/);
});
