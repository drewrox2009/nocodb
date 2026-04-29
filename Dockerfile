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

# Install all dependencies at the root
# This ensures all hoisted dependencies (like vue) are available for all packages
RUN pnpm install --frozen-lockfile

# Build internal dependencies in order
RUN pnpm --filter nocodb-sdk run build
RUN pnpm --filter nocodb-sdk-v2 run build
RUN pnpm --filter nocodb-integrations run build

# Build Frontend
WORKDIR /usr/app/packages/nc-gui
RUN npx nuxt build --spa

# Build Backend
WORKDIR /usr/app/packages/nocodb
# Ensure the public directory exists and copy the frontend build into it
RUN mkdir -p src/public && cp -r ../nc-gui/.output/public/* src/public/
# Build the production bundle
RUN npx rspack --config rspack.config.js

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
