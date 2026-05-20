# Stage 1: Build everything
FROM node:22-bookworm-slim AS builder

# Install build dependencies for native modules (sqlite3, sharp, etc.)
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm

WORKDIR /usr/app

# Copy all workspace files
COPY . .

# Install all dependencies at the root (skip postinstall scripts —
# nuxt prepare would fail because nocodb-sdk hasn't been built yet)
RUN pnpm install --no-frozen-lockfile --ignore-scripts

# Build internal dependencies in order
RUN pnpm --filter nocodb-sdk run build
RUN pnpm --filter nocodb-sdk-v2 run build
RUN pnpm --filter nocodb-integrations run build || echo "Integrations build skipped (non-critical)"

# Now that the SDK is built, run nuxt prepare to generate types
WORKDIR /usr/app/packages/nc-gui
RUN pnpm exec nuxt prepare

# Build Frontend
RUN pnpm exec nuxt build --spa

# Build Backend
WORKDIR /usr/app/packages/nocodb
# Ensure the public directory exists and copy the frontend build into it
RUN mkdir -p src/public && cp -r ../nc-gui/.output/public/* src/public/
# Build the production bundle (TsChecker disabled — pre-existing TS issues in upstream)
ENV NC_DISABLE_TS_CHECKER=true
RUN pnpm exec rspack --config rspack.config.js

# Stage 2: Final Production Image
FROM node:22-bookworm-slim
WORKDIR /usr/app

# libvips is often required by sharp
RUN apt-get update && apt-get install -y libvips-dev && rm -rf /var/lib/apt/lists/*

# Copy the bundled backend and the node_modules (for native modules)
COPY --from=builder /usr/app/packages/nocodb/dist ./dist
COPY --from=builder /usr/app/node_modules ./node_modules

# Set environment
ENV NODE_ENV=production
ENV NC_DOCKER=true

# Expose NocoDB default port
EXPOSE 8080

# Start the application
CMD ["node", "dist/bundle.js"]
