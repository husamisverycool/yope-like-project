# syntax=docker/dockerfile:1
# Web service (invite page, association files). Build from the repository root, because the image
# carries config/app.json (the single source of app identity):
#   docker build -f web/Dockerfile -t web .
#   docker run -p 8080:8080 -e SUPABASE_URL=… -e SUPABASE_ANON_KEY=… -e SUPABASE_SERVICE_ROLE_KEY=… web
# NODE_IMAGE may point at a mirror of the official image, e.g.
#   --build-arg NODE_IMAGE=public.ecr.aws/docker/library/node:22.22.0-bookworm-slim
# In production the container refuses to start while a BLOCKED copy string or config value remains.

ARG NODE_IMAGE=node:22.22.0-bookworm-slim

FROM ${NODE_IMAGE} AS build
WORKDIR /app/web
COPY web/package.json web/package-lock.json web/.npmrc ./
# Optional CA for builds behind a TLS-inspecting proxy: --secret id=ca,src=<bundle.pem>
RUN --mount=type=secret,id=ca,required=false \
    if [ -f /run/secrets/ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/ca; fi; npm ci
COPY web/tsconfig.json web/tsconfig.build.json ./
COPY web/src ./src
RUN npm run build && npm prune --omit=dev

FROM ${NODE_IMAGE}
ENV NODE_ENV=production \
    PORT=8080 \
    APP_CONFIG_PATH=/app/config/app.json
WORKDIR /app/web
COPY web/package.json ./
COPY --from=build /app/web/node_modules ./node_modules
COPY --from=build /app/web/dist ./dist
COPY config/app.json /app/config/app.json
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]
CMD ["node", "dist/main.js"]
