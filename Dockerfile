# Match the Flutter and Dart toolchain used to validate this repository.
FROM debian:bookworm-slim AS flutter-build

ARG FLUTTER_VERSION=3.47.2
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
ENV PUB_CACHE=/opt/pub-cache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl git libglu1-mesa unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl --fail --location --retry 5 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt

WORKDIR /workspace/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY app/lib ./lib
COPY app/assets ./assets
COPY app/web ./web
RUN flutter build web --release --no-pub

FROM node:24-bookworm-slim AS runtime

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    OSCAR_PREVIEW_OPEN_BROWSER=0
WORKDIR /workspace

COPY --from=flutter-build --chown=node:node /workspace/app/build/web ./app/build/web
COPY --chown=node:node tools/serve_web_preview.mjs ./tools/serve_web_preview.mjs
COPY --chown=node:node tools/coinmarketcap_proxy.mjs ./tools/coinmarketcap_proxy.mjs
COPY --chown=node:node tools/persistent_market_cache.mjs ./tools/persistent_market_cache.mjs

USER node
EXPOSE 10000
CMD ["node", "tools/serve_web_preview.mjs"]
