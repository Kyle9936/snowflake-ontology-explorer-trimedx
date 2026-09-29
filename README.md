# MMD Ontology Explorer (TriMedx)

Deploy an **Ontology-on-Snowflake knowledge graph** for medical device fleet management into your own account, then **visualize and explore it** in a local web app. The repo ships everything end to end: synthetic (deliberately messy) device data across three source systems, the SQL that builds a full ontology layer on top of it, and a React + Express app that renders the ontology as a graph and lets you chat with a Cortex Agent over it.

> **Forked from [sfc-gh-ccaudill/snowflake-ontology-explorer](https://github.com/sfc-gh-ccaudill/snowflake-ontology-explorer)** and re-skinned for the TriMedx MMD (Make, Model, Description) use case. The original healthcare demo's architecture, framework, and patterns are preserved - only the domain data, ontology classes, and UI copy have been replaced.

## What this is / when to use it

Use this repo to:
- **Demo MMD device matching to TriMedx** - show, on realistic messy data, why manufacturer aliases and model number inconsistencies break naive matching and how an ontology resolves them.
- **Stand up a working ontology + Cortex Agent fast** - one command builds the graph, semantic views, and agents.
- **Explore an ontology visually** - the web app renders the class graph, the resolved instance graph, and each class's cross-system source mappings.
- **Show the before/after** - toggle between the ontology agent (full resolution) and the baseline agent (raw tables) to demonstrate the accuracy difference.

## The MMD problem

### Business context

TriMedx's sales team prices the cost of managing a new hospital site's medical device fleet by matching every device on the incoming inventory to a known Make, Model, and Description (MMD) record. That MMD record is what links a device to its parts replacement costs, maintenance schedules, failure rates, and service labor estimates - all of which drive the quote.

**Incorrect device matching can result in thousands of dollars of difference per device in pricing quotes**, making accurate identification crucial for new site takeovers and customer pricing. Across a fleet of hundreds of devices, these errors compound into significant financial exposure.

### Where they are today

| Metric | Current state |
|--------|--------------|
| **Auto-match rate** | ~20% of devices are matched automatically on first pass |
| **Overall match rate** | ~90% total (after manual review) |
| **Manual review** | ~80% of matches require human review |
| **Goal** | Increase automation by 20% through AI enhancements and data quality improvements |

The team is actively building AI solutions and cleaner combined datasets (FDA + proprietary sources) to improve matching accuracy. This demo shows what an ontology-grounded approach looks like on Snowflake.

### Why matching is hard

The same device appears differently across sources:

| Source | Example (same device) |
|--------|----------------------|
| FDA GUDID registry | "GE Healthcare" / "CARESCAPE Monitor B650" / "B650 v2" |
| TriMedx master catalog | "GE" / "B650" / "Bedside patient monitor" |
| Site inventory | "GE B650" or "G.E. Carescape B650" or "Gen Electric B650" |

Manufacturer names alone have dozens of variants ("GE Healthcare", "General Electric Co", "GE Medical Systems", "GE", "G.E.", "Gen Electric", "GE Med Sys"). Add model number formatting differences, legacy acquisition names (Toshiba -> Canon, Covidien -> Medtronic), and free-text descriptions, and the matching problem becomes combinatorial.

## Prerequisites

- A Snowflake account in a **Cortex-enabled region** (the semantic views + agent use Cortex Analyst).
- A role that can `CREATE DATABASE` (e.g. `SYSADMIN`) and a warehouse (e.g. `COMPUTE_WH`). **The build role itself needs `USAGE` on that warehouse** - not just your user via another role. The Cortex Search service refreshes as its owner role, so if the warehouse is owned by `ACCOUNTADMIN` with no grant, the deploy fails with *"warehouse ... is missing"*. Fix: `GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SYSADMIN;`
- **Snowflake CLI** (`snow`) with a connection in `~/.snowflake/connections.toml`. Check with `snow connection list`. The deploy defaults to a connection named `DEMO` - override with `SNOWFLAKE_CONNECTION` in `config.env`.
- For the web app only: **Node 18+** and a **key-pair** connection (the browser cannot sign JWTs).

## Deploy the data + ontology

```bash
# Copy the config and set SNOWFLAKE_CONNECTION to your connection.
cp config.env.example config.env      # then edit - at minimum, set SNOWFLAKE_CONNECTION

./deploy.sh                 # load data -> build ontology -> verify
./deploy.sh render          # only render SQL into ./build (to paste into a worksheet)
./deploy.sh verify          # run count assertions against your deployment
./deploy.sh teardown        # DROP the demo databases (asks to confirm)
```

`./deploy.sh` loads the three source systems ([`sql/data/`](sql/data/)) and then builds the ontology stack ([`sql/ontology/`](sql/ontology/)). Everything is parameterized through `config.env`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `SNOWFLAKE_CONNECTION` | `DEMO` | which `connections.toml` entry to deploy with |
| `BUILD_ROLE` / `WAREHOUSE` | `SYSADMIN` / `COMPUTE_WH` | role + warehouse for the build |
| `EMR_DB` / `EMR_SCHEMA` | `FDA_DEVICES` / `GUDID` | FDA device registry source |
| `CLAIMS_DB` / `CLAIMS_SCHEMA` | `TRIMEDX_MMD` / `MASTER` | TriMedx master MMD catalog |
| `RX_DB` / `RX_SCHEMA` | `SITE_INVENTORY` / `RAW` | incoming site inventory |
| `ONTOLOGY_DB` / `ONTOLOGY_SCHEMA` | `=EMR_DB` / `ONTOLOGY` | where the ontology is built |

## Explore it in the web app

[`ontology-explorer/`](ontology-explorer/) is a local React + Express app that:
- **Visualizes the ontology as a network graph** (both the class model and the resolved instance graph)
- **Inspects each class's cross-system source mappings** with live sample rows
- **Chats with a Cortex Agent** over the ontology (with a baseline agent toggle for comparison)

```bash
cd ontology-explorer
npm install && npm run install:all
npm run dev                 # backend :3001 + frontend :5173 -> open http://localhost:5173
```

Configure the backend with `server/.env`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `SNOWFLAKE_CONNECTION_NAME` | `DEMO` | connection from `connections.toml` (needs key-pair auth) |
| `CORTEX_AGENT_NAME` | _(unset)_ | set to `FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_AGENT` to enable live chat |

## Why an ontology? (the payoff)

The ontology resolves device identity across all three source systems into one connected graph:

```
Device ──made_by──> Manufacturer
   │
   ├── belongs_to_family ──> DeviceFamily ──has_pm_schedule──> MaintenanceSchedule
   │
   ├── has_fda_record ──> FDARecord
   │
   ├── has_cost ──> ServiceCost (annual parts + labor + PM)
   │
   └── matched_to <── SiteEquipment ──located_in──> Department ──part_of_site──> Site
```

**The "killer" demo question:** *"What is the estimated annual maintenance cost for this site's device fleet?"*
Measured results, same question to both agents:

| | Baseline agent (raw tables) | MMD Ontology Agent |
|---|---|---|
| Devices priced | 34 of 140 (24%) | 138 of 139 (99.3%) |
| Estimated annual fleet cost | $268,700 (a floor) | $1,222,400 |
| Wrong matches | n/a | 0 (verified row by row) |
| Left for review | 106 unpriced | 1 (Acme FP-100, not in the TriMedx catalog) |

- **Baseline:** the site's free-text model strings only join to the TriMedx catalog on an exact match, so 76% of the fleet can't be priced. That 24% lines up with TriMedx's real-world ~20% first-pass auto-match rate.
- **Ontology:** matching is layered, and a wrong match is treated as worse than no match, because it produces a confident wrong price:
  1. **Rules** - `FN_NORMALIZE_MFR` resolves manufacturer aliases and acquisitions; `FN_NORMALIZE_MODEL` normalizes model strings (`PB 840` = `PB840`, `Servo U` = `Servo-u`). `EXACT_MODEL`, then `FUZZY_MODEL`. If two catalog devices tie, nothing is guessed.
  2. **Cortex Search** (`CSS_DEVICE_CATALOG`, via `CORTEX_SEARCH_BATCH`) - semantic matching over the catalog. Auto-accepted as `SEARCH_MATCH` only when cosine >= 0.55 and >= 0.05 ahead of the runner-up.
  3. **Review** - anything else is `NEEDS_REVIEW`, with Cortex Search's suggestion pre-filled.

**Rules vs Cortex Search.** The alias list was written against this demo dataset, so the rules result is optimistic: the next site brings variants no one has written a rule for yet. As a fair test, Cortex Search was run on all 139 devices *with no alias list at all*. It ranked the correct catalog device first for all 138 matchable devices, and its confidence gate auto-accepted 127 of them with zero errors. The 11 it held back were close calls between sibling models (Puritan Bennett 980 vs 840, Carescape B650 vs B850) - exactly the look-alikes with different service costs. On the 138 rule matches, Cortex Search independently chose the same device every time (`SEARCH_AGREES`).

## What you deploy (at a glance)

`./deploy.sh` builds, in `FDA_DEVICES.ONTOLOGY`, a full Ontology-on-Snowflake Knowledge-Graph stack:

- **100 FDA device records** across 20+ manufacturers with deliberate naming inconsistencies
- **100 TriMedx catalog entries** with device families, PM schedules, and annual cost estimates
- **140 site inventory records** from a 450-bed hospital with ~15% hard-to-match entries
- A **physical KG** (`KG_NODE` / `KG_EDGE`) with 583 nodes and 748 edges
- **9 ontology classes** (Device, Manufacturer, DeviceFamily, SiteEquipment, ServiceCost, MaintenanceSchedule, FDARecord, Site, Department) and **8 relationships**
- **4 Cortex Analyst semantic views** (base, KG, ontology, metadata), with **6 verified queries** on the KG view (fleet cost, match rate, match method, cost by department, unmatched devices, search confirmation)
- **A Cortex Search service** (`CSS_DEVICE_CATALOG`) over the TriMedx catalog, used for batch matching and as a live agent tool
- **2 Cortex Agents** - the full MMD Ontology Agent (9 intent-routed tools, including Cortex Search) and a baseline agent for comparison
- **Manufacturer alias resolution** via `FN_NORMALIZE_MFR` (handles 50+ name variants)
- **Layered device matching**: EXACT_MODEL -> FUZZY_MODEL -> SEARCH_MATCH -> NEEDS_REVIEW, with ties never auto-priced

## The source data's deliberate messiness

The demo works because the synthetic data has specific, realistic messiness:

1. **Same device, different names** - "GE Carescape B650" (TriMedx) vs "GE Healthcare CARESCAPE Monitor B650" (FDA) vs "GE B650" (site)
2. **Manufacturer alias chaos** - "GE Healthcare", "General Electric Co", "GE Medical Systems", "GE", "G.E.", "Gen Electric", "GE Med Sys" are all one company
3. **Missing identity keys** - not every device has an FDA DI; some site entries lack model numbers
4. **Acquisition name changes** - "Toshiba" is now Canon Medical; "Covidien" is now Medtronic; "CareFusion" is now BD; "Maquet" is now Getinge
5. **Model number formatting** - FDA includes revision suffixes (B650 v2, A500 SW 3.0); TriMedx uses short codes (B650, A500); site uses whatever the tech typed
6. **Overloaded inventory rows** - each EQUIPMENT_LIST row carries device + location + service history + condition
7. **Unmatched devices = unpriced risk** - every device that fails matching has no cost estimate, so the quote underestimates
8. **Look-alike models, different prices** - sibling models (PB 980 vs PB 840, B650 vs B850) are close in name but not in service cost

See [`sql/data/README.md`](sql/data/README.md) for the original alignment challenge reference.

## Repo layout

```
snowflake-ontology-explorer-trimedx/
├── README.md                 # this file
├── ADAPTING.md               # how the original healthcare demo was re-skinned
├── config.env.example        # deploy config (copy to config.env)
├── deploy.sh                 # one-command render + deploy + verify + teardown
├── scripts/
│   └── render.pl             # parameterization engine
├── sql/
│   ├── data/                 # the three messy source systems
│   │   ├── 01_fda_devices.sql      # FDA_DEVICES.GUDID - 100 GUDID device records
│   │   ├── 02_trimedx_mmd.sql      # TRIMEDX_MMD.MASTER - catalog, manufacturers, families, PM, costs
│   │   ├── 03_site_inventory.sql   # SITE_INVENTORY.RAW - 140 messy equipment records + site/departments
│   │   └── README.md
│   └── ontology/             # the ontology stack, one SQL file per build phase
│       ├── 01_phase4_layers_1-3.sql                     # KG + resolution, metadata, views, UDFs
│       ├── 02_phase4.5_base_semantic_view.sql           # base semantic view (raw tables)
│       ├── 03_phase5_ontology_layer_semantic_views.sql  # KG / Ontology / Metadata semantic views
│       ├── 04_phase6_cortex_agents.sql                  # MMD Ontology Agent + baseline agent
│       ├── verify.sql                                   # post-deploy count assertions
│       ├── teardown.sql                                 # drop the demo databases
│       └── README.md
└── ontology-explorer/        # local React + Express app: graph viz, class inspector, agent chat
```

**Run order:** `./deploy.sh` handles it. Manually: `sql/data/01 -> 02 -> 03` then `sql/ontology/01 -> 02 -> 03 -> 04`, all as a `CREATE DATABASE`-capable role.
