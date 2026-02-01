#!/bin/sh
set -e

# Ensure .openclaw directory exists in the mounted volume
mkdir -p /data/.openclaw

# Copy config if it doesn't exist (don't overwrite existing config)
if [ ! -f /data/.openclaw/openclaw.json ]; then
  echo "Creating initial openclaw.json config..."
  cat > /data/.openclaw/openclaw.json <<'EOF'
{
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "password"
    },
    "trustedProxies": ["0.0.0.0/0"],
    "dm": {
      "policy": "open",
      "allowFrom": ["*"]
    }
  }
}
EOF
fi

# Ensure workspace directory exists
mkdir -p /data/workspace

# Execute the CMD
exec "$@"
