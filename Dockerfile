# Stage 1: Build the frontend
FROM node:22-slim AS frontend-builder
RUN npm install -g pnpm
WORKDIR /usr/app
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/nocodb-sdk/package.json ./packages/nocodb-sdk/
COPY packages/nocodb-sdk-v2/package.json ./packages/nocodb-sdk-v2/
COPY packages/nc-gui/package.json ./packages/nc-gui/
RUN pnpm install --filter nocodb-sdk --filter nocodb-sdk-v2 --filter nc-gui
COPY . .
RUN pnpm --filter nocodb-sdk run build
RUN pnpm --filter nocodb-sdk-v2 run build
# Build the Nuxt frontend
WORKDIR /usr/app/packages/nc-gui
RUN npx nuxt build --spa

# Stage 2: Build the backend and assemble
FROM node:22-slim AS backend-builder
RUN npm install -g pnpm
WORKDIR /usr/app
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/nocodb/package.json ./packages/nocodb/
COPY packages/noco-integrations/package.json ./packages/noco-integrations/
COPY packages/nc-secret-mgr/package.json ./packages/nc-secret-mgr/
RUN pnpm install --filter nocodb --filter noco-integrations --filter nc-secret-mgr
COPY . .
# Copy frontend build to backend public folder
COPY --from=frontend-builder /usr/app/packages/nc-gui/.output/public ./packages/nocodb/src/public
# Build integrations and backend
RUN pnpm run integrations:build
WORKDIR /usr/app/packages/nocodb
RUN npx rspack --config rspack.config.js

# Stage 3: Final Production Image
FROM node:22-slim
WORKDIR /usr/app

# Install production dependencies only if needed, but since we bundle everything with Rspack,
# we mostly need the dist and node_modules for native dependencies like sqlite3/sharp.
COPY --from=backend-builder /usr/app/packages/nocodb/dist ./dist
COPY --from=backend-builder /usr/app/node_modules ./node_modules

# Set environment
ENV NODE_ENV=production
ENV NC_DOCKER=true

# Expose port
EXPOSE 8080

# Start the application
CMD ["node", "dist/bundle.js"]
