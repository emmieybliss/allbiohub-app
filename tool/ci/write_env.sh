#!/usr/bin/env bash
# Writes the build settings for CI to the file named in $1: .env.example with
# the Firebase values filled in from the repository's Actions secrets, when
# they are set. Keeps those values out of Git.
set -euo pipefail

out="$1"
cp .env.example "$out"
for key in FIREBASE_PROJECT_ID FIREBASE_API_KEY FIREBASE_APP_ID FIREBASE_MESSAGING_SENDER_ID; do
  value="${!key:-}"
  if [ -n "$value" ]; then
    # Values are ids and keys made of [A-Za-z0-9:_-], so no escaping needed.
    sed -i "s|^$key=.*|$key=$value|" "$out"
  fi
done

if grep -q '^FIREBASE_API_KEY=.\+' "$out"; then
  echo "Firebase settings found: notifications and analytics are on."
else
  echo "No Firebase secrets: this build has notifications and analytics off."
fi
