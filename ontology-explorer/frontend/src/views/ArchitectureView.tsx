import { useEffect, useLayoutEffect, useRef, useState } from 'react';

/**
 * Architecture view — a static, color-coded diagram of the ontology stack,
 * laid out left→right as five layers. Data flows from raw storage on the left
 * through the ontology (metadata + generated views) into semantic models and,
 * finally, the agent + its knowledge-graph tools on the right.
 *
 * Object names are the real deployed objects in FDA_DEVICES.ONTOLOGY (+ the
 * three source databases).
 */

interface Card {
  name: string;
  sub?: string;
  tag?: string; // small corner tag, e.g. system name
}

/** A faint decorative node/edge network drawn behind Layers 2 & 3. */
function OntologyNetwork() {
  // Positions are in % of the zone box.
  const nodes = [
    { x: 12, y: 22 }, { x: 30, y: 12 }, { x: 48, y: 26 }, { x: 66, y: 14 },
    { x: 86, y: 24 }, { x: 20, y: 52 }, { x: 40, y: 62 }, { x: 58, y: 50 },
    { x: 78, y: 60 }, { x: 92, y: 48 }, { x: 14, y: 82 }, { x: 34, y: 88 },
    { x: 52, y: 78 }, { x: 72, y: 86 }, { x: 88, y: 78 },
  ];
  const edges = [
    [0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [2, 6], [3, 7], [4, 9],
    [5, 6], [6, 7], [7, 8], [8, 9], [5, 10], [6, 12], [7, 12],
    [8, 13], [10, 11], [11, 12], [12, 13], [13, 14],
  ];
  return (
    <svg className="arch-net" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden>
      {edges.map(([a, b], i) => (
        <line key={i} x1={nodes[a].x} y1={nodes[a].y} x2={nodes[b].x} y2={nodes[b].y} />
      ))}
      {nodes.map((n, i) => (
        <circle key={i} cx={n.x} cy={n.y} r={i % 3 === 0 ? 1.6 : 1.1} />
      ))}
    </svg>
  );
}

function LayerCol({
  cls,
  n,
  title,
  children,
  innerRef,
}: {
  cls: string;
  n: string;
  title: string;
  children: React.ReactNode;
  innerRef?: React.Ref<HTMLElement>;
}) {
  return (
    <section className={`arch-layer ${cls}`} ref={innerRef}>
      <header className="arch-head">
        <span className="arch-head-n">{n}</span>
        <span className="arch-head-t">{title}</span>
      </header>
      <div className="arch-body">{children}</div>
    </section>
  );
}

function Cards({ items }: { items: Card[] }) {
  return (
    <>
      {items.map((c) => (
        <div className="arch-card" key={c.name}>
          {c.tag && <span className="arch-card-tag">{c.tag}</span>}
          <div className="arch-card-name">{c.name}</div>
          {c.sub && <div className="arch-card-sub">{c.sub}</div>}
        </div>
      ))}
    </>
  );
}

const Flow = () => <div className="arch-flow" aria-hidden>→</div>;

const VERIFIED_QUERIES = [
  'Fleet cost',
  'Match rate',
  'Match method',
  'Cost by department',
  'Unmatched devices',
  'Search confirmation',
];

/**
 * The bypass path: raw tables go straight to the Base semantic view with no
 * ontology in between. That is the "before" in the base-vs-ontology agent
 * comparison. Drawn as an elbow under the stack, anchored to measured DOM
 * positions so it tracks the layout on resize.
 */
function BypassArrow({
  stage,
  from,
  to,
}: {
  stage: React.RefObject<HTMLDivElement | null>;
  from: React.RefObject<HTMLDivElement | null>;
  to: React.RefObject<HTMLElement | null>;
}) {
  const [geo, setGeo] = useState<{ sx: number; sy: number; ex: number; ey: number; lane: number } | null>(null);

  useLayoutEffect(() => {
    const measure = () => {
      if (!stage.current || !from.current || !to.current) return;
      const s = stage.current.getBoundingClientRect();
      const a = from.current.getBoundingClientRect();
      const b = to.current.getBoundingClientRect();
      setGeo({
        sx: a.left + a.width / 2 - s.left,
        sy: a.bottom - s.top,
        ex: b.left + b.width / 2 - s.left,
        ey: b.bottom - s.top,
        lane: Math.max(a.bottom, b.bottom) - s.top + 26,
      });
    };
    measure();
    const ro = new ResizeObserver(measure);
    if (stage.current) ro.observe(stage.current);
    window.addEventListener('resize', measure);
    return () => {
      ro.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, [stage, from, to]);

  if (!geo) return null;
  const { sx, sy, ex, ey, lane } = geo;
  return (
    <>
      <svg className="arch-bypass" aria-hidden>
        <defs>
          <marker id="bypass-head" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="7" markerHeight="7" orient="auto">
            <path d="M0,0 L10,5 L0,10 z" />
          </marker>
        </defs>
        <path d={`M${sx},${sy} V${lane} H${ex} V${ey + 4}`} markerEnd="url(#bypass-head)" />
      </svg>
      <div className="arch-bypass-label" style={{ left: (sx + ex) / 2, top: lane }}>
        Bypass: raw tables → Base semantic view, no ontology. The "before" in the agent comparison.
      </div>
    </>
  );
}

export default function ArchitectureView() {
  // Fade the diagram in once mounted (nice on tab switch).
  const [ready, setReady] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const rawRef = useRef<HTMLDivElement>(null);
  const l4Ref = useRef<HTMLElement>(null);
  useEffect(() => {
    const t = setTimeout(() => setReady(true), 30);
    return () => clearTimeout(t);
  }, []);

  return (
    <div className={`arch ${ready ? 'ready' : ''}`} ref={ref}>
      <div className="arch-intro">
        <h2>Ontology architecture</h2>
        <p>
          Five layers, left to right. Raw source data is resolved into a knowledge graph (with
          Cortex Search for fuzzy device matching), described by ontology metadata, exposed as
          generated views and semantic views with verified queries, and finally reasoned over by
          the agent. The dashed path underneath is the shortcut most teams take today: semantic
          views straight on raw tables, no ontology.
        </p>
      </div>

      <div className="arch-scroll">
        <div className="arch-stage" ref={stageRef}>
          {/* ---------- Layer 1: Physical Storage (raw + KG tables) ---------- */}
          <section className="arch-layer l1 arch-l1">
            <header className="arch-head">
              <span className="arch-head-n">Layer 1</span>
              <span className="arch-head-t">Physical Storage</span>
            </header>
            <div className="arch-body arch-l1-body">
              <div className="arch-group" ref={rawRef}>
                <div className="arch-group-title">Raw source tables</div>
                <Cards
                  items={[
                    { name: 'DEVICE_RECORD', sub: 'GUDID registry entries', tag: 'FDA' },
                    { name: 'DEVICE_CATALOG', sub: 'MANUFACTURER · DEVICE_FAMILY · PM_SCHEDULE', tag: 'Trimedx' },
                    { name: 'EQUIPMENT_LIST', sub: 'SITE_INFO · DEPARTMENT', tag: 'Site' },
                  ]}
                />
              </div>
              <div className="arch-inner-flow" aria-hidden>→</div>
              <div className="arch-group kg">
                <div className="arch-group-title">Knowledge graph</div>
                <Cards
                  items={[
                    { name: 'KG_NODE', sub: 'canonical entities' },
                    { name: 'KG_EDGE', sub: 'typed relationships' },
                    { name: 'CSS_DEVICE_CATALOG', sub: 'Cortex Search · fuzzy MMD matching', tag: 'search' },
                  ]}
                />
              </div>
            </div>
          </section>

          <Flow />

          {/* ---------- Ontology zone wraps Layers 2 & 3 ---------- */}
          <div className="arch-onto-zone">
            <OntologyNetwork />
            <div className="arch-onto-ribbon">The ontology lives here</div>
            <div className="arch-onto-inner">
              <LayerCol cls="l2 arch-l2" n="Layer 2" title="Ontology Metadata">
                <Cards
                  items={[
                    { name: 'ONT_CLASS', sub: 'classes & hierarchy' },
                    { name: 'ONT_PROPERTY', sub: 'attributes' },
                    { name: 'ONT_RELATION_DEF', sub: 'relationships' },
                    { name: 'ONT_OBJECT_SOURCE', sub: 'class → source table' },
                    { name: 'ONT_IDENTITY_RULE', sub: 'entity resolution' },
                    { name: 'ONT_CLASS_MAP', sub: 'source → class mapping' },
                  ]}
                />
              </LayerCol>

              <Flow />

              <LayerCol cls="l3 arch-l3" n="Layer 3" title="Generated Views">
                <div className="arch-subhead">Entities</div>
                <Cards
                  items={[
                    { name: 'V_DEVICE' },
                    { name: 'V_MANUFACTURER' },
                    { name: 'V_SITE_EQUIPMENT' },
                    { name: 'V_SERVICE_COST' },
                  ]}
                />
                <div className="arch-subhead">Relationships</div>
                <Cards
                  items={[
                    { name: 'V_REL_MADE_BY' },
                    { name: 'V_REL_MATCHED_TO' },
                    { name: 'V_REL_HAS_COST' },
                  ]}
                />
                <div className="arch-subhead">Resolved graph</div>
                <Cards
                  items={[
                    { name: 'REL_RESOLVED' },
                    { name: 'VW_ONT_ALL_ENTITIES' },
                  ]}
                />
              </LayerCol>
            </div>
          </div>

          <Flow />

          {/* ---------- Layer 4: Semantic Models ---------- */}
          <LayerCol cls="l4 arch-l4" n="Layer 4" title="Semantic Views" innerRef={l4Ref}>
            <Cards
              items={[
                { name: 'Base', sub: 'MMD_ONTOLOGY_BASE', tag: 'bypass' },
                { name: 'Ontology', sub: 'MMD_ONTOLOGY_ONTOLOGY_MODEL', tag: 'resolved' },
                { name: 'Governance', sub: 'MMD_ONTOLOGY_METADATA_MODEL', tag: 'metadata' },
                { name: 'Knowledge Graph', sub: 'MMD_ONTOLOGY_KG_MODEL', tag: 'star' },
              ]}
            />
            <div className="arch-subhead">Verified queries · KG view</div>
            <div className="arch-chips">
              {VERIFIED_QUERIES.map((q) => (
                <span className="arch-chip vq" key={q}>✓ {q}</span>
              ))}
            </div>
          </LayerCol>

          <Flow />

          {/* ---------- Layer 5: Intelligent Orchestration ---------- */}
          <LayerCol cls="l5 arch-l5" n="Layer 5" title="Intelligent Orchestration">
            <div className="arch-agent">
              <div className="arch-agent-icon">✦</div>
              <div>
                <div className="arch-agent-name">MMD_ONTOLOGY_AGENT</div>
                <div className="arch-agent-sub">Cortex Agent · plans &amp; routes</div>
              </div>
            </div>
            <div className="arch-subhead">Analyst tools → models</div>
            <div className="arch-chips">
              {['base_query_tool', 'kg_query_tool', 'ontology_query_tool', 'metadata_query_tool'].map((t) => (
                <span className="arch-chip" key={t}>{t}</span>
              ))}
            </div>
            <div className="arch-subhead">Search tool → catalog</div>
            <div className="arch-chips">
              <span className="arch-chip search">catalog_search_tool</span>
            </div>
            <div className="arch-subhead">KG traversal tools</div>
            <div className="arch-chips">
              {['get_ancestors', 'expand_descendants', 'get_direct_children', 'get_hierarchy_path'].map((t) => (
                <span className="arch-chip alt" key={t}>{t}</span>
              ))}
            </div>
          </LayerCol>
          <BypassArrow stage={stageRef} from={rawRef} to={l4Ref} />
        </div>
      </div>
    </div>
  );
}
