# syntax=docker/dockerfile:1

FROM golang:1.24-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libtesseract-dev \
        libleptonica-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags "-s -w" -o /out/idscan-server ./cmd/server

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tesseract-ocr \
        tesseract-ocr-eng \
        libtesseract5 \
        liblept5 \
    && rm -rf /var/lib/apt/lists/*

# gosseract calls libtesseract directly, which does not use the Debian
# tesseract wrapper's compiled-in data path.
ENV TESSDATA_PREFIX=/usr/share/tesseract-ocr/5/tessdata \
    PORT=8080

WORKDIR /app

COPY --from=builder /out/idscan-server /app/idscan-server
COPY web /app/web

RUN useradd --system --uid 65532 --no-create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

ENTRYPOINT ["/app/idscan-server"]
