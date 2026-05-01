# elko-fatcat-mcp-community

Public distribution repo for [elko-fatcat-mcp](https://hub.docker.com/r/jsoprych/elko-fatcat-mcp) —
the free fat cat monitor MCP server.

Track where powerful entities put their money:
- **SEC Form 13F** — hedge fund & institutional holdings (~4,700 filers, quarterly)
- **SEC Form 4** — corporate insider trades (executives, directors, daily)
- **STOCK Act** — congressional member trades (House + Senate PTR disclosures)
- **Congress Members** — profiles, sponsored legislation, and campaign donors

> **Note:** This repo contains docs and deployment files only.
> The source code is private. The Docker image is freely available.

---

## Quickstart

```bash
git clone https://github.com/jsoprych/elko-fatcat-mcp-community
cd elko-fatcat-mcp-community
make start
```

Dashboard: http://localhost:8083

Or with raw Docker:

```bash
docker run -d --name elko-fatcat \
  -p 8083:8083 \
  -v elko-fatcat-data:/data \
  jsoprych/elko-fatcat-mcp:latest
```

---

## MCP Tools (10)

| Tool | Source | Description |
|------|--------|-------------|
| `fatcat_13f_holdings` | edgar | Holdings for a specific fund (by CIK or name) |
| `fatcat_13f_changes` | edgar | Quarter-over-quarter position diff |
| `fatcat_13f_ticker` | edgar | Which funds hold a given ticker |
| `fatcat_13f_top_moves` | edgar | Biggest position changes across all filers |
| `fatcat_insider_trades` | edgar | Form 4 buys/sells by company or insider |
| `fatcat_congress_trades` | congress | STOCK Act trades by member/ticker/party |
| `fatcat_ingest_status` | internal | Warehouse status and last ingest dates |
| `fatcat_member_profile` | congress | "Follow the money" profile: trades + bills + donors |
| `fatcat_member_legislation` | congress | Recent bills sponsored by a member |
| `fatcat_member_donors` | congress | Top campaign donors by employer |

---

## Claude Desktop / Cursor Setup

```bash
# After starting the container:
curl -s http://localhost:8083/mcp.json > .mcp.json
```

Add `.mcp.json` to your MCP client config. The `/mcp` endpoint requires no API key.

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ELKO_EASY_KEY` | No | Pre-baked in image. Override to customize rate limits. |
| `ELKO_KEY_SECRET` | No | HMAC secret for pro-key validation (higher limits) |
| `ELKO_REVOCATION_URL` | No | Pro-key revocation endpoint |
| `CONGRESS_API_KEY` | No | Congress.gov API key (free) — required for legislation ingest |
| `FEC_API_KEY` | No | FEC API key (optional) — defaults to DEMO_KEY with lower rate limits |

The built-in easy key has RPM and RPD limits baked into the image. For higher throughput
supply `ELKO_KEY_SECRET` (pro key) or override `ELKO_EASY_KEY` with a custom token.

Get free API keys:
- Congress.gov: [api.congress.gov/sign-up](https://api.congress.gov/sign-up/)
- FEC: [api.data.gov/signup](https://api.data.gov/signup/)

---

## Data Freshness

| Source | Lag | Scope |
|--------|-----|-------|
| 13F (quarterly) | 45 days after quarter end | ~4,700 filers with $100M+ AUM |
| Form 4 (daily) | 2 business days | All public company insiders |
| House PTR | 45 days | ~435 Representatives |
| Senate PTR | 45 days | 100 Senators (3-month rolling window) |
| Congress Members | Real-time | All 535 members, party, state, photo |
| Campaign Donors (FEC) | Per FEC filing | Top employer donors per member |
| Sponsored Legislation | ~1 day | Recent bills per member (API key required) |

Background ingest runs automatically. First start backfills full history — expect
5–15 minutes for 13F (4 quarters, ~80 MB ZIP) + Form 4 (1 year) + congressional data,
depending on network. Subsequent starts are incremental (seconds to minutes).

---

## docker-compose with optional API keys

```yaml
services:
  elko-fatcat:
    image: jsoprych/elko-fatcat-mcp:latest
    ports:
      - "8083:8083"
    volumes:
      - elko-fatcat-data:/data
    environment:
      - ELKO_KEY_SECRET=${ELKO_KEY_SECRET:-}
      - ELKO_REVOCATION_URL=${ELKO_REVOCATION_URL:-}
      - CONGRESS_API_KEY=${CONGRESS_API_KEY:-}
      - FEC_API_KEY=${FEC_API_KEY:-}
    restart: unless-stopped

volumes:
  elko-fatcat-data:
```

Create a `.env` file in the same directory to set your keys without editing compose:

```
CONGRESS_API_KEY=your_key_here
FEC_API_KEY=your_key_here
```

---

## Tool Parameters

Each tool's full input schema is available from the running server:

```bash
curl -s http://localhost:8083/v1/catalogue | jq '.tools[] | {name, inputSchema}'
```

Common parameters across tools:

| Tool | Key Parameters |
|------|---------------|
| `fatcat_13f_holdings` | `fund_name` or `cik`, optional `quarter` (YYYY-QN), `limit` |
| `fatcat_13f_changes` | `fund_name` or `cik`, optional `quarter` (YYYY-QN), `action` (new/added/trimmed/exited) |
| `fatcat_13f_ticker` | `ticker`, optional `quarter`, `min_value_m` (millions), `limit` |
| `fatcat_13f_top_moves` | optional `action`, `quarter`, `limit` |
| `fatcat_insider_trades` | `ticker` or `name`, optional `code` (P/S/A/D), `months`, `limit` |
| `fatcat_congress_trades` | optional `member`, `ticker`, `party` (D/R/I), `type` (purchase/sale), `months`, `limit` |
| `fatcat_member_profile` | `member` (name or bioguide ID) |
| `fatcat_member_legislation` | `member`, optional `limit` |
| `fatcat_member_donors` | `member`, optional `cycle` (e.g. 2024), `limit` |
| `fatcat_ingest_status` | no parameters |

---

## REST API

```bash
# Health check
curl http://localhost:8083/health

# Tool catalogue
curl http://localhost:8083/v1/catalogue

# Call a tool
curl -X POST http://localhost:8083/v1/call/fatcat_congress_trades \
  -H "X-API-Key: YOUR_EASY_KEY" \
  -H "Content-Type: application/json" \
  -d '{"ticker":"NVDA","months":12}'

# Member profile (follow the money)
curl -X POST http://localhost:8083/v1/call/fatcat_member_profile \
  -H "X-API-Key: YOUR_EASY_KEY" \
  -H "Content-Type: application/json" \
  -d '{"member":"Pelosi"}'

# OpenAPI spec (ChatGPT Actions, n8n, Zapier)
curl http://localhost:8083/openapi.json
```

---

## SQL Procedures

The dashboard Procedures panel lets you define custom SQL queries that are
automatically registered as MCP tools. JOINs across all data sources are supported:

```sql
-- Smart money + Congress overlap
SELECT h.ticker,
       COUNT(DISTINCT h.cik) AS hedge_funds,
       COUNT(DISTINCT c.member_name) AS congress_members
FROM holdings_13f h
JOIN congress_trades c ON UPPER(h.ticker) = UPPER(c.ticker)
WHERE h.report_date = (SELECT MAX(report_date) FROM holdings_13f)
GROUP BY h.ticker
ORDER BY hedge_funds DESC
LIMIT 25
```

Three examples are seeded on first start.

---

## Makefile Targets

```
make start     # Start container (docker compose up -d)
make stop      # Stop container
make down      # Remove container (keep volume)
make clean     # Full reset (container + volume + image)
make logs      # Follow logs
make rebuild   # Force rebuild + restart
make status    # Container status
```

---

## Version Pinning

To pin to a specific release instead of always pulling `:latest`:

```yaml
image: jsoprych/elko-fatcat-mcp:0.1.0
```

Run `make rebuild` to pull the latest image and restart.

---

## Troubleshooting

**Container exits immediately**
- Check logs: `make logs`
- Ensure the data volume is writable: `docker volume inspect elko-fatcat-data`

**No data after startup**
- Ingest takes 5–15 min on first run. Check `make logs` for progress.
- Call `fatcat_ingest_status` to see record counts and last ingest timestamps.

**Legislation data missing**
- `CONGRESS_API_KEY` is required. Get one free at [api.congress.gov/sign-up](https://api.congress.gov/sign-up/).

**401 on REST API calls**
- Pass your easy key in the `X-API-Key` header. Retrieve it from `/v1/key-status`.

**Rate limited**
- The built-in easy key has RPM/RPD limits. Supply `ELKO_KEY_SECRET` for a pro key,
  or override `ELKO_EASY_KEY` with a custom token.

---

## License

Docker image: free to use.
Source: private (see [elko.ai](https://elko.ai)).
