# syntax=docker/dockerfile:1
# Worker image: Node 22 + ffmpeg (libx264, AAC) + Roboto. Build from the repository root, because
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
# Roboto Serif Headline + Inter (SIL OFL, see fonts/SOURCE.txt): read by path for server-rendered text, also registered with fontconfig
COPY backend/worker/fonts ./fonts
RUN mkdir -p /usr/share/fonts/truetype/app \
 && cp fonts/*.ttf /usr/share/fonts/truetype/app/ \
 && fc-cache -f
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
