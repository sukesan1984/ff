# Flappy Fever — 静的配信 + ランキングAPI を兼ねる Go サーバ
# build stage(ビルドホストのarchで動かし amd64 へクロスコンパイル=高速)
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build
WORKDIR /src
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/*.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /server .

# web 圧縮ステージ(事前gzip。Cloud Run の 32MiB レスポンス上限回避 & 高速化)
FROM alpine AS web
COPY build/web /web
RUN find /web -type f \( -name '*.wasm' -o -name '*.js' -o -name '*.pck' -o -name '*.html' -o -name '*.json' \) -exec gzip -9 -k {} \;

# runtime stage(非root・最小・CA証明書同梱の distroless)
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /server /server
COPY --from=web /web /web
ENV STATIC_DIR=/web
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
