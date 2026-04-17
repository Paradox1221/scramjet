# Deploying Scramjet

Scramjet requires a Node.js server that supports **long-running processes and WebSocket upgrades**. It cannot be deployed to purely static hosts (Vercel, Netlify, GitHub Pages).

The easiest path is to deploy the pre-built Docker image included in this repo (`Dockerfile`). Pick any of the options below.

---

## Option A – Railway (recommended for speed)

1. [Sign up / log in](https://railway.app) and install the [Railway CLI](https://docs.railway.app/develop/cli):
   ```sh
   npm install -g @railway/cli
   railway login
   ```
2. From the repo root:
   ```sh
   railway init          # create a new project
   railway up            # build & deploy (uses Dockerfile + railway.toml)
   ```
3. Railway will print a public URL when done.

> The `railway.toml` in this repo handles the rest automatically.

---

## Option B – Render

1. [Sign up / log in](https://render.com).
2. Click **New → Blueprint** and connect your GitHub fork of this repo.  
   Render will detect `render.yaml` and create the service automatically.
3. Click **Apply** – Render builds the Docker image and gives you a `*.onrender.com` URL.

Alternatively, create a **Web Service** manually:
- **Runtime**: Docker  
- **Dockerfile Path**: `./Dockerfile`  
- **Environment Variable**: `CI=1`

---

## Option C – Fly.io

1. [Sign up / log in](https://fly.io) and install `flyctl`:
   ```sh
   curl -L https://fly.io/install.sh | sh
   fly auth login
   ```
2. From the repo root:
   ```sh
   # First time only – provision the app (edit fly.toml app name if desired first)
   fly launch --no-deploy

   # Deploy
   fly deploy
   ```
3. Fly will print your `https://<appname>.fly.dev` URL.

> The `fly.toml` pre-configures port 8080, HTTPS, and CI mode.

---

## Option D – Any VPS / Docker host

```sh
# Build
docker build -t scramjet .

# Run (map container port 8080 to host port 80)
docker run -d --restart unless-stopped -p 80:8080 scramjet
```

Then point a domain at your server's IP, or just access `http://<server-ip>`.

---

## Option E – Local + Cloudflare Tunnel (instant public URL, no server)

```sh
pnpm dev                      # starts on http://localhost:1337
# in another terminal:
cloudflared tunnel --url http://localhost:1337
```

Cloudflare Tunnel prints a `https://*.trycloudflare.com` URL you can share immediately.

---

## Build notes

The Docker build (~10–20 min on first run) installs:
- Rust nightly + `wasm32-unknown-unknown` target
- `wasm-bindgen-cli` 0.2.100 (exact version required)
- `wasm-opt` from [binaryen](https://github.com/WebAssembly/binaryen)
- `wasm-snip` from the [r58playz fork](https://github.com/r58playz/wasm-snip)

Subsequent builds are fast because Docker layer-caches the Rust toolchain and Cargo installs unless those steps change.
