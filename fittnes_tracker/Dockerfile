# Trainer Console web bundle. The API this talks to stays on Cloud Run —
# this image only builds and serves the static Flutter web build, matching
# what .github/workflows/web.yml already builds (same flags), plus the nginx
# SPA fallback that CI's uploaded artifact never needed because nothing
# served it with routing.
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Baked in at build time, not read at runtime: serverUrlDefault
# (lib/feature/auth/presentation/providers/auth_provider.dart) is a
# String.fromEnvironment, resolved when the JS bundle is compiled. Point this
# at the Cloud Run API's public URL. Trailing slash matters — see
# docs/cors-and-signalr.md on origin comparison for why the API side is
# fussy about exact strings; the client concatenates paths onto this one.
ARG FORGE_API_URL
RUN flutter build web --release --no-web-resources-cdn \
    --dart-define=FORGE_API_URL=${FORGE_API_URL}

FROM nginx:alpine AS runtime
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
