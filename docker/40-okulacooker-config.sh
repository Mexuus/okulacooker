#!/bin/sh
# Writes /tmp/okulacooker-config.json from environment variables so one image can
# be hosted anywhere. nginx serves it as config.json; the app reads it at start.
#   OKULACOOKER_SECURE_URL  https address of this app, offered when it's opened over
#                       plain http (browsers block location there).
set -eu

url="${OKULACOOKER_SECURE_URL:-}"
case "$url" in
  https://*) ;;
  "") ;;
  *) echo "okulacooker: ignoring OKULACOOKER_SECURE_URL (must start with https://)" >&2; url="" ;;
esac
# Keep only URL-safe characters so the value can't break out of the JSON string.
url=$(printf '%s' "$url" | tr -cd 'A-Za-z0-9._~:/?#@!$&()*+,;=%-')

if [ -n "$url" ]; then
  printf '{"secureUrl":"%s"}\n' "$url" > /tmp/okulacooker-config.json
  echo "okulacooker: secure URL is $url"
else
  printf '{}\n' > /tmp/okulacooker-config.json
fi
