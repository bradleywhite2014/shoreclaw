# Build openclaw from source (official template approach)
FROM node:22-bookworm AS openclaw-build

# Dependencies needed for openclaw build
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Install Bun (openclaw build uses it)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /openclaw

# Clone official OpenClaw (pinned to last known working version)
ARG OPENCLAW_GIT_REF=2026.1.30
RUN git clone --depth 1 --branch "${OPENCLAW_GIT_REF}" https://github.com/openclaw/openclaw.git . || \
    git clone https://github.com/openclaw/openclaw.git . && git checkout tags/2026.1.30

# Patch: relax version requirements
RUN set -eux; \
  find ./extensions -name 'package.json' -type f | while read -r f; do \
    sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*">=[^"]+"/"openclaw": "*"/g' "$f"; \
    sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*"workspace:[^"]+"/"openclaw": "*"/g' "$f"; \
  done

RUN pnpm install --no-frozen-lockfile
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install && pnpm ui:build

# Apply Shore AgentOS branding to the built UI
COPY ui/public/shore_agent.png /openclaw/ui/dist/shore_agent.png
RUN sed -i 's/shoreclaw\.png/shore_agent.png/g' /openclaw/ui/dist/index.html
RUN sed -i 's/OpenClaw/Shore AgentOS/g' /openclaw/ui/dist/index.html

# Runtime image
FROM node:22-bookworm
ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Wrapper deps
COPY railway-wrapper-package.json package.json
RUN npm install --omit=dev && npm cache clean --force

# Copy built openclaw (includes everything, including templates)
COPY --from=openclaw-build /openclaw /openclaw

# Copy templates from local source (they may not survive the build)
COPY docs/reference/templates /openclaw/docs/reference/templates

# Provide an openclaw executable
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /openclaw/dist/index.js "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

COPY src ./src

# The wrapper listens on this port
ENV OPENCLAW_PUBLIC_PORT=8080
ENV PORT=8080
EXPOSE 8080
CMD ["node", "src/server.js"]
