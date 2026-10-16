# syntax=docker/dockerfile:1
# Worker image: Node 22 + ffmpeg (libx264, AAC) + the app's fonts and the fallback fonts. Build from the repository root, because
# the worker reads design token proposals from design/ until they are merged:
#   docker build -f backend/worker/Dockerfile -t worker .
# NODE_IMAGE may point at a mirror of the official image (e.g. public.ecr.aws/docker/library/node:22-slim)
ARG NODE_IMAGE=node:22-slim
FROM ${NODE_IMAGE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg ca-certificates fontconfig \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend/worker
COPY backend/worker/package.json backend/worker/package-lock.json ./
# Behind a TLS-intercepting proxy, pass its CA as a build secret:
#   docker build --secret id=build_ca,src=/path/to/ca.pem --build-arg HTTPS_PROXY=... -f backend/worker/Dockerfile .
RUN --mount=type=secret,id=build_ca,required=false \
    if [ -f /run/secrets/build_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/build_ca npm_config_cafile=/run/secrets/build_ca; fi \
 && npm ci --omit=dev && npm cache clean --force

COPY backend/worker/tsconfig.json ./
COPY backend/worker/src ./src
# Roboto Serif Headline + Inter (SIL OFL, see fonts/SOURCE.txt) and fonts/fonts.conf, which src/tribute/render.ts hands to
# fontconfig (FONTCONFIG_FILE): those faces, then the fallback set for other scripts and colour emoji — no system fonts.
COPY backend/worker/fonts ./fonts
# Fallback fonts (SIL OFL, fonts/fallback/SOURCE.txt): Noto scripts 10.2 MB + colour emoji 5.0 MB.
# Same relative place as in the repository (fonts.conf: ../../../fonts/fallback/…).
COPY fonts/fallback/SOURCE.txt /app/fonts/fallback/SOURCE.txt
COPY fonts/fallback/scripts /app/fonts/fallback/scripts
COPY fonts/fallback/emoji-color /app/fonts/fallback/emoji-color
# design token proposals (collage, platform, tribute) and copy patterns, read at runtime
COPY design/proposals /app/design/proposals
COPY design/*.md /app/design/

ENV NODE_ENV=production PORT=8080
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
# SIGTERM → graceful shutdown (in-flight jobs finish or are released back to the queue)
STOPSIGNAL SIGTERM
CMD ["node", "--import", "tsx", "src/main.ts"]
