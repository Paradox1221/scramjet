# ─── Stage 1: Build ────────────────────────────────────────────────────────────
# Needs Rust (nightly + wasm32), wasm-bindgen, wasm-opt, wasm-snip, Node, pnpm.
FROM node:22-bookworm AS builder

WORKDIR /app

# System build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

# Rust (nightly – required by rewriter/rust-toolchain.toml)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain nightly \
    && . "$HOME/.cargo/env" \
    && rustup target add wasm32-unknown-unknown \
    && rustup component add rust-src

ENV PATH="/root/.cargo/bin:$PATH"

# wasm-bindgen-cli – must be exactly 0.2.100 (checked by build.sh)
RUN cargo install wasm-bindgen-cli --version 0.2.100

# wasm-opt (binaryen) – detect arch so this works on arm64 too
RUN ARCH=$(uname -m) \
    && VER=$(curl -fsSI https://github.com/WebAssembly/binaryen/releases/latest \
             | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n') \
    && curl -fsSL \
        "https://github.com/WebAssembly/binaryen/releases/download/${VER}/binaryen-${VER}-${ARCH}-linux.tar.gz" \
        | tar xz \
    && mv "binaryen-${VER}/bin/wasm-opt" /usr/local/bin/ \
    && rm -rf "binaryen-${VER}"

# wasm-snip – must be the r58playz fork (upstream is abandoned)
RUN cargo install --git https://github.com/r58playz/wasm-snip

# pnpm
RUN npm install -g pnpm

# ── Copy source and build ───────────────────────────────────────────────────────

COPY . .

# Install JS deps (preinstall hook only checks we're using pnpm, so this is fine)
RUN pnpm install --frozen-lockfile

# Build the Rust/WASM rewriter in release mode
RUN RELEASE=1 pnpm rewriter:build

# Build the Scramjet bundle
RUN pnpm build

# ─── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM node:22-slim AS runtime

WORKDIR /app

# Copy only what the server needs at runtime
COPY --from=builder /app/package.json   ./package.json
COPY --from=builder /app/server.js      ./server.js
COPY --from=builder /app/static         ./static
COPY --from=builder /app/dist           ./dist
COPY --from=builder /app/lib            ./lib
COPY --from=builder /app/node_modules   ./node_modules

# CI=1 disables the rspack watch-mode dev loop in server.js
ENV CI=1
ENV PORT=8080

EXPOSE 8080

CMD ["node", "server.js"]
