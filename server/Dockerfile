# The Playwright version decides which Chromium runs. The image and the npm
# package must match, so both come from this one value; the nightly updater on
# the server raises it (see deploy/ansible/roles/secureqr/files/secureqr-update.sh).
ARG PLAYWRIGHT_VERSION=1.65.0

FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble AS build
ARG PLAYWRIGHT_VERSION
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci && npm install --no-save --no-audit --no-fund playwright@${PLAYWRIGHT_VERSION}
COPY tsconfig.json ./
COPY src ./src
RUN npm run build \
 && npm prune --omit=dev \
 && npm install --no-save --no-audit --no-fund --omit=dev playwright@${PLAYWRIGHT_VERSION} \
 && node -e "const v=require('playwright/package.json').version; if (v !== '${PLAYWRIGHT_VERSION}') { console.error('playwright is ' + v); process.exit(1) }"

FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
USER pwuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/index.js"]
