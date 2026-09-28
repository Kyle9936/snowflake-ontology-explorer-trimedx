/**
 * Canonical ontology definition for the MMD (Make, Model, Description) demo.
 *
 * This is a hand-authored model for the TriMedx device fleet management use
 * case. It renders a meaningful, explorable graph showing how medical devices
 * connect across FDA, TriMedx, and site inventory sources.
 *
 * The frontend depends only on the JSON shape below (GROUPS, NODES, EDGES,
 * getOntology). No React changes needed.
 */

import {
    EMR_DB, EMR_SCHEMA, CLAIMS_DB, CLAIMS_SCHEMA, RX_DB, RX_SCHEMA,
    ONTOLOGY_DB, ONTOLOGY_SCHEMA, EHR,
} from './dbconfig.js';

export const GROUPS = {
    device: { label: 'Device', color: '#29B5E8' },
    operations: { label: 'Operations', color: '#7442BF' },
    financial: { label: 'Financial', color: '#F59F3B' },
    place: { label: 'Place', color: '#11567F' },
    regulatory: { label: 'Regulatory', color: '#2FA84F' },
};

const NODES = [
    {
        id: 'Device',
        label: 'Device',
        group: 'device',
        description:
            'A canonical medical device from the TriMedx MMD catalog. Resolves naming variants across FDA, TriMedx, and site inventories into one identity. The same device may appear as "GE Carescape B650" (TriMedx), "GE Healthcare CARESCAPE Monitor B650" (FDA), and "GE B650" or "G.E. Carescape B650" (site inventory).',
        properties: [
            { name: 'catalogId', description: 'TriMedx internal catalog identifier (canonical key)' },
            { name: 'tmxModel', description: 'TriMedx model designation' },
            { name: 'deviceName', description: 'Short commercial device name' },
            { name: 'canonicalMfr', description: 'Resolved manufacturer name via FN_NORMALIZE_MFR' },
            { name: 'familyName', description: 'Device family for pricing and PM scheduling' },
            { name: 'fdaDi', description: 'FDA GUDID identifier (nullable - not all devices linked to FDA)' },
            { name: 'fdaClass', description: 'FDA risk classification (1, 2, or 3)' },
        ],
        mappings: [
            { system: CLAIMS_DB, table: 'DEVICE_CATALOG', note: 'Canonical anchor; MODEL_NUMBER + DEVICE_NAME + FDA_DI' },
            { system: EMR_DB, table: 'DEVICE_RECORD', note: 'Enrichment via GUDID_DI; regulatory description + classification' },
            { system: RX_DB, table: 'EQUIPMENT_LIST', note: 'Resolved via degrading-hierarchy matching (exact model > fuzzy model > description)' },
        ],
        sampleQuery:
            `select CATALOG_ID, MODEL_NUMBER, DEVICE_NAME, DEVICE_DESC, FDA_DI from ${CLAIMS_DB}.${CLAIMS_SCHEMA}.DEVICE_CATALOG limit 8`,
    },
    {
        id: 'Manufacturer',
        label: 'Manufacturer',
        group: 'device',
        description:
            'A device manufacturer. Resolves aliases across systems: "GE Healthcare" (FDA), "GE" (TriMedx), "G.E." / "Gen Electric" / "GE Med Sys" (site inventories) all map to one canonical Manufacturer.',
        properties: [
            { name: 'mfrId', description: 'TriMedx manufacturer ID (canonical key)' },
            { name: 'canonicalName', description: 'Resolved via FN_NORMALIZE_MFR' },
            { name: 'mfrShort', description: 'TriMedx internal abbreviation (GE, Phil, Siemens)' },
            { name: 'fdaNameVariants', description: 'All distinct FDA COMPANY_NAME values for this manufacturer' },
            { name: 'mfrCountry', description: 'Country of origin' },
        ],
        mappings: [
            { system: CLAIMS_DB, table: 'MANUFACTURER', note: 'MFR_ID + MFR_NAME (abbreviated)' },
            { system: EMR_DB, table: 'DEVICE_RECORD', note: 'COMPANY_NAME (free-text, multiple variants per mfr)' },
            { system: RX_DB, table: 'EQUIPMENT_LIST', note: 'MANUFACTURER (wildly inconsistent free-text)' },
        ],
        sampleQuery:
            `select MFR_ID, MFR_NAME, MFR_FULL_NAME, MFR_COUNTRY from ${CLAIMS_DB}.${CLAIMS_SCHEMA}.MANUFACTURER limit 8`,
    },
    {
        id: 'DeviceFamily',
        label: 'Device Family',
        group: 'operations',
        description:
            'A logical grouping of similar devices for pricing, PM scheduling, and fleet analysis. Examples: Bedside Monitors, CT Scanners, Critical Care Ventilators, Infusion Pumps. TriMedx-only concept not present in FDA or site data.',
        properties: [
            { name: 'familyId', description: 'Family identifier' },
            { name: 'familyName', description: 'Display name (e.g. "Bedside Monitors")' },
            { name: 'familyCategory', description: 'Broad category (Patient Monitoring, Diagnostic Imaging, etc.)' },
            { name: 'avgUsefulLifeYears', description: 'Typical useful life for devices in this family' },
        ],
        mappings: [
            { system: CLAIMS_DB, table: 'DEVICE_FAMILY', note: 'FAMILY_ID + FAMILY_NAME + FAMILY_CATEGORY' },
        ],
        sampleQuery:
            `select FAMILY_ID, FAMILY_NAME, FAMILY_CATEGORY, AVG_USEFUL_LIFE_YEARS from ${CLAIMS_DB}.${CLAIMS_SCHEMA}.DEVICE_FAMILY limit 8`,
    },
    {
        id: 'SiteEquipment',
        label: 'Site Equipment',
        group: 'place',
        description:
            'A physical device instance at the site being onboarded. This is the raw inventory record with free-text manufacturer, model, and description fields. The ontology resolves each to a canonical Device (or marks it unmatched).',
        properties: [
            { name: 'equipId', description: 'Site-assigned equipment identifier' },
            { name: 'rawMfr', description: 'Original manufacturer text (may be abbreviated or misspelled)' },
            { name: 'rawModel', description: 'Original model text (may include brand name or just a number)' },
            { name: 'rawDesc', description: 'Free-text description from site CMMS export' },
            { name: 'isMatched', description: 'Whether this equipment was resolved to a canonical Device' },
            { name: 'matchBasis', description: 'EXACT_MODEL / FUZZY_MODEL / DESC_MATCH' },
        ],
        mappings: [
            { system: RX_DB, table: 'EQUIPMENT_LIST', note: 'EQUIP_ID + free-text MANUFACTURER / MODEL / DEVICE_DESCRIPTION' },
        ],
        sampleQuery:
            `select EQUIP_ID, MANUFACTURER, MODEL, DEVICE_DESCRIPTION, SERIAL_NUMBER, CONDITION from ${RX_DB}.${RX_SCHEMA}.EQUIPMENT_LIST limit 8`,
    },
    {
        id: 'ServiceCost',
        label: 'Service Cost',
        group: 'financial',
        description:
            'Annual service cost estimate for a specific device model. Includes parts, labor, PM, and total costs. This drives the site quote - wrong device matching means wrong cost assumptions.',
        properties: [
            { name: 'catalogId', description: 'Links to the Device this cost applies to' },
            { name: 'annualPartsCost', description: 'Estimated annual parts spend' },
            { name: 'annualLaborCost', description: 'Estimated annual labor cost' },
            { name: 'annualTotalCost', description: 'Total annual service cost' },
            { name: 'riskTier', description: 'HIGH / MEDIUM / LOW' },
            { name: 'costConfidence', description: 'How reliable the estimate is' },
        ],
        mappings: [
            { system: CLAIMS_DB, table: 'SERVICE_COST_ESTIMATE', note: 'CATALOG_ID + annual cost breakdown + risk tier' },
        ],
        sampleQuery:
            `select CATALOG_ID, ANNUAL_PARTS_COST, ANNUAL_LABOR_COST, ANNUAL_TOTAL_COST, RISK_TIER from ${CLAIMS_DB}.${CLAIMS_SCHEMA}.SERVICE_COST_ESTIMATE limit 8`,
    },
    {
        id: 'MaintenanceSchedule',
        label: 'Maintenance Schedule',
        group: 'operations',
        description:
            'Preventive maintenance template defining PM type (FULL_PM, INTERIM_PM, CALIBRATION, SAFETY_CHECK), interval in months, and estimated technician hours. Linked to DeviceFamily, not individual devices.',
        properties: [
            { name: 'pmId', description: 'PM schedule identifier' },
            { name: 'pmType', description: 'FULL_PM / INTERIM_PM / CALIBRATION / SAFETY_CHECK' },
            { name: 'intervalMonths', description: 'How often (months between PMs)' },
            { name: 'estLaborHours', description: 'Estimated tech time per PM event' },
        ],
        mappings: [
            { system: CLAIMS_DB, table: 'PM_SCHEDULE', note: 'PM_ID + FAMILY_ID + PM_TYPE + INTERVAL_MONTHS' },
        ],
        sampleQuery:
            `select PM_ID, FAMILY_ID, PM_TYPE, INTERVAL_MONTHS, EST_LABOR_HOURS from ${CLAIMS_DB}.${CLAIMS_SCHEMA}.PM_SCHEDULE limit 8`,
    },
    {
        id: 'FDARecord',
        label: 'FDA Record',
        group: 'regulatory',
        description:
            'An FDA GUDID registry entry. Contains the official device description, risk classification, and product code. Manufacturer names in FDA records are free-text and inconsistent even for the same company.',
        properties: [
            { name: 'gudidDi', description: 'Global Unique Device Identifier' },
            { name: 'companyName', description: 'FDA free-text manufacturer (varies per record)' },
            { name: 'brandName', description: 'Commercial brand name' },
            { name: 'versionModelNumber', description: 'FDA model/version (may include revision suffixes)' },
            { name: 'deviceClass', description: 'FDA risk class: 1, 2, or 3' },
            { name: 'productCode', description: '3-letter FDA product code' },
        ],
        mappings: [
            { system: EMR_DB, table: 'DEVICE_RECORD', note: 'GUDID_DI + COMPANY_NAME + VERSION_MODEL_NUMBER + DEVICE_DESCRIPTION' },
        ],
        sampleQuery:
            `select GUDID_DI, COMPANY_NAME, BRAND_NAME, VERSION_MODEL_NUMBER, DEVICE_CLASS from ${EMR_DB}.${EMR_SCHEMA}.DEVICE_RECORD limit 8`,
    },
    {
        id: 'Site',
        label: 'Site',
        group: 'place',
        description:
            'A hospital or facility being onboarded for device management. Contains bed count, location, and onboarding date.',
        properties: [
            { name: 'siteId', description: 'Site identifier' },
            { name: 'siteName', description: 'Hospital/facility name' },
            { name: 'siteType', description: 'HOSPITAL / SURGERY_CENTER / CLINIC' },
            { name: 'bedCount', description: 'Number of beds' },
        ],
        mappings: [
            { system: RX_DB, table: 'SITE_INFO', note: 'SITE_ID + SITE_NAME + BED_COUNT' },
        ],
        sampleQuery:
            `select * from ${RX_DB}.${RX_SCHEMA}.SITE_INFO`,
    },
    {
        id: 'Department',
        label: 'Department',
        group: 'place',
        description:
            'A department or unit within the site (ICU, OR Suite, Radiology, etc.). Site naming conventions may differ from TriMedx standards.',
        properties: [
            { name: 'deptId', description: 'Department identifier' },
            { name: 'deptName', description: 'Department name (site convention)' },
            { name: 'floor', description: 'Floor number or label' },
            { name: 'wing', description: 'Wing (East, West, North, South, Central)' },
        ],
        mappings: [
            { system: RX_DB, table: 'DEPARTMENT', note: 'DEPT_ID + DEPT_NAME + FLOOR + WING' },
        ],
        sampleQuery:
            `select * from ${RX_DB}.${RX_SCHEMA}.DEPARTMENT limit 8`,
    },
];

const LINKS = [
    { source: 'Device', target: 'Manufacturer', label: 'made_by', description: 'Device is manufactured by' },
    { source: 'Device', target: 'DeviceFamily', label: 'belongs_to_family', description: 'Device belongs to a logical family for pricing and PM' },
    { source: 'Device', target: 'FDARecord', label: 'has_fda_record', description: 'Device links to its FDA GUDID registry entry' },
    { source: 'Device', target: 'ServiceCost', label: 'has_cost', description: 'Device has an annual service cost estimate' },
    { source: 'DeviceFamily', target: 'MaintenanceSchedule', label: 'has_pm_schedule', description: 'Family defines PM schedule templates' },
    { source: 'SiteEquipment', target: 'Device', label: 'matched_to', description: 'Site inventory resolved to a canonical Device via degrading-hierarchy matching' },
    { source: 'SiteEquipment', target: 'Department', label: 'located_in', description: 'Equipment is installed in this department' },
    { source: 'Department', target: 'Site', label: 'part_of_site', description: 'Department belongs to the site' },
];

export function getOntology() {
    const nodes = NODES.map((n) => ({
        id: n.id,
        label: n.label,
        group: n.group,
        color: GROUPS[n.group]?.color,
        degree: LINKS.filter((l) => l.source === n.id || l.target === n.id).length,
    }));
    return { nodes, links: LINKS, groups: GROUPS };
}

export function getNodeDetail(id) {
    const node = NODES.find((n) => n.id === id);
    if (!node) return null;
    const relationships = LINKS.filter((l) => l.source === id || l.target === id).map((l) => ({
        label: l.label,
        direction: l.source === id ? 'out' : 'in',
        other: l.source === id ? l.target : l.source,
    }));
    return { ...node, color: GROUPS[node.group]?.color, groupLabel: GROUPS[node.group]?.label, relationships };
}

export function getNodeSampleQuery(id) {
    return NODES.find((n) => n.id === id)?.sampleQuery || null;
}

/* =========================================================================
   Source-system model - the three ORIGINAL databases
   ========================================================================= */

export const SOURCE_SYSTEMS = [
    {
        db: EMR_DB,
        schema: EMR_SCHEMA,
        label: 'FDA Device Registry',
        color: '#2FA84F',
        description: 'FDA GUDID registry. Manufacturer names are free-text and inconsistent across records.',
        tables: [
            { name: 'DEVICE_RECORD', description: 'One row per unique device identifier. COMPANY_NAME varies for the same manufacturer.' },
        ],
    },
    {
        db: CLAIMS_DB,
        schema: CLAIMS_SCHEMA,
        label: 'TriMedx Master MMD',
        color: '#29B5E8',
        description: 'TriMedx proprietary catalog. Abbreviated manufacturer names (GE, Phil, Siemens).',
        tables: [
            { name: 'MANUFACTURER', description: 'Canonical manufacturer list with TriMedx-internal abbreviations.' },
            { name: 'DEVICE_CATALOG', description: 'The master MMD table - Make, Model, Description for every known device.' },
            { name: 'DEVICE_FAMILY', description: 'Logical device groupings for pricing and PM scheduling.' },
            { name: 'PM_SCHEDULE', description: 'Preventive maintenance templates by device family.' },
            { name: 'SERVICE_COST_ESTIMATE', description: 'Annual service cost per device model - drives the quote.' },
        ],
    },
    {
        db: RX_DB,
        schema: RX_SCHEMA,
        label: 'Incoming Site Inventory',
        color: '#F59F3B',
        description: 'Raw equipment inventory from the site being onboarded. Free-text, wildly inconsistent.',
        tables: [
            { name: 'SITE_INFO', description: 'The hospital being onboarded.' },
            { name: 'DEPARTMENT', description: 'Departments within the site.' },
            { name: 'EQUIPMENT_LIST', description: 'Overloaded: device + location + service history in one row. Manufacturer and model are free-text.', overloaded: true },
        ],
    },
];

export const LINKAGE_KINDS = {
    device_id: { label: 'FDA DI - device identity (strong)', color: '#2FA84F' },
    manufacturer: { label: 'Manufacturer name - alias resolution', color: '#29B5E8' },
    model: { label: 'Model number - fuzzy match', color: '#7442BF' },
    family: { label: 'Device family - grouping key', color: '#F59F3B' },
    catalog: { label: 'Catalog ID - TriMedx internal', color: '#11567F' },
};

export function classifyColumn(name) {
    const u = String(name).toUpperCase();
    if (u.includes('GUDID') || u === 'FDA_DI') return { kind: 'device_id', label: 'FDA GUDID - strong device identity link' };
    if (u.includes('MFR') || u === 'MANUFACTURER' || u === 'COMPANY_NAME') return { kind: 'manufacturer', label: 'Manufacturer name - needs alias resolution' };
    if (u.includes('MODEL') || u === 'VERSION_MODEL_NUMBER') return { kind: 'model', label: 'Model number - fuzzy match across systems' };
    if (u.includes('FAMILY_ID')) return { kind: 'family', label: 'Device family - TriMedx grouping key' };
    if (u === 'CATALOG_ID') return { kind: 'catalog', label: 'TriMedx catalog ID - canonical device key' };
    return null;
}

function classesForTable(systemDb, tableName) {
    return NODES.filter((n) =>
        n.mappings.some(
            (m) =>
                m.system === systemDb &&
                m.table.split(/[/,]/).map((t) => t.trim()).includes(tableName)
        )
    ).map((n) => ({ id: n.id, label: n.label, color: GROUPS[n.group]?.color }));
}

export function getSourceModel() {
    return SOURCE_SYSTEMS.map((sys) => ({
        ...sys,
        tables: sys.tables.map((t) => ({
            ...t,
            classes: classesForTable(sys.db, t.name),
        })),
    }));
}

export const ONTOLOGY_METADATA = [
    {
        db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Classes & relations', color: '#8b5cf6',
        description: 'The class hierarchy and relationship definitions.',
        tables: [
            { name: 'ONT_CLASS', description: 'Every ontology class + its parent.' },
            { name: 'ONT_RELATION_DEF', description: 'Typed relationships between classes.' },
            { name: 'ONT_CLASS_MAP', description: 'Maps source labels to ontology classes.' },
        ],
    },
    {
        db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Sources & identity', color: '#a855f7',
        description: 'Provenance + the rules that resolve one device across systems.',
        tables: [
            { name: 'ONT_OBJECT_SOURCE', description: 'Which source table/column each class draws from.' },
            { name: 'ONT_IDENTITY_RULE', description: 'Device resolution rules (FDA_DI, model match, desc match).' },
        ],
    },
    {
        db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Knowledge-graph store', color: '#0ea5a4',
        description: 'The resolved graph the ontology is materialized into.',
        tables: [
            { name: 'KG_NODE', description: 'Canonical resolved entities (one row per real-world thing).' },
            { name: 'KG_EDGE', description: 'Typed relationships between canonical nodes.' },
        ],
    },
];

export const GENERATED_VIEWS = [
    {
        db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Entity views', color: '#29b5e8',
        description: 'One resolved view per ontology class.',
        tables: [
            { name: 'V_DEVICE', description: 'Canonical devices resolved across all three systems.' },
            { name: 'V_MANUFACTURER', description: 'Canonical manufacturers with all name variants.' },
            { name: 'V_DEVICE_FAMILY', description: 'Device families for pricing and PM.' },
            { name: 'V_SITE_EQUIPMENT', description: 'Site inventory with match status.' },
            { name: 'V_SERVICE_COST', description: 'Annual cost estimates per device.' },
            { name: 'V_MAINTENANCE_SCHEDULE', description: 'PM schedule templates.' },
            { name: 'V_FDA_RECORD', description: 'FDA GUDID records.' },
            { name: 'V_SITE', description: 'Hospital sites.' },
            { name: 'V_DEPARTMENT', description: 'Departments within sites.' },
        ],
    },
    {
        db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Relationship views', color: '#1e9fd0',
        description: 'Resolved edges between entities.',
        tables: [
            { name: 'V_REL_MADE_BY', description: 'Device manufactured by Manufacturer.' },
            { name: 'V_REL_BELONGS_TO_FAMILY', description: 'Device belongs to DeviceFamily.' },
            { name: 'V_REL_HAS_COST', description: 'Device has ServiceCost.' },
            { name: 'V_REL_HAS_FDA_RECORD', description: 'Device links to FDARecord.' },
            { name: 'V_REL_HAS_PM', description: 'DeviceFamily has MaintenanceSchedule.' },
            { name: 'V_REL_MATCHED_TO', description: 'SiteEquipment matched to Device.' },
            { name: 'V_REL_LOCATED_IN', description: 'SiteEquipment in Department.' },
            { name: 'V_REL_PART_OF_SITE', description: 'Department belongs to Site.' },
        ],
    },
    {
        db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Resolved & hierarchy', color: '#11567f',
        description: 'Unified entity/edge feeds and class-hierarchy helpers.',
        tables: [
            { name: 'VW_ONT_ALL_ENTITIES', description: 'All resolved entities across every class.' },
            { name: 'REL_RESOLVED', description: 'All resolved edges (src/dst joined to entities).' },
            { name: 'VW_ONT_HIERARCHY_STATS', description: 'Per-class instance counts.' },
            { name: 'VW_MATCH_SUMMARY', description: 'Match rate and cost summary for the site.' },
            { name: 'VW_SITE_COST_ESTIMATE', description: 'Per-device cost estimate with match status.' },
        ],
    },
];

function withEmptyClasses(model) {
    return model.map((s) => ({ ...s, tables: s.tables.map((t) => ({ ...t, classes: [] })) }));
}

export function getSourceDatasets() {
    return [
        { key: 'raw', label: 'Raw tables', description: 'The three original source databases, exactly as each stores its data.', systems: getSourceModel() },
        { key: 'metadata', label: 'Ontology metadata', description: 'The metadata tables that DEFINE the ontology - classes, relations, identity rules.', systems: withEmptyClasses(ONTOLOGY_METADATA) },
        { key: 'views', label: 'Generated views', description: 'The views the ontology generates - resolved entities and relationships.', systems: withEmptyClasses(GENERATED_VIEWS) },
    ];
}

export function isKnownObject(db, schema, table) {
    const all = [SOURCE_SYSTEMS, ONTOLOGY_METADATA, GENERATED_VIEWS].flat();
    return all.some(
        (s) => s.db === db && s.schema === schema && s.tables.some((t) => t.name === table)
    );
}

export const CHALLENGES = [
    { id: 1, title: 'Same device, different names', blurb: '"GE Carescape B650" (TriMedx) vs "GE Healthcare CARESCAPE Monitor B650" (FDA) vs "GE B650" (site). The ontology resolves them to one canonical Device.' },
    { id: 2, title: 'Manufacturer alias chaos', blurb: '"GE Healthcare", "General Electric Co", "GE Medical Systems", "GE", "G.E.", "Gen Electric", "GE Med Sys" - all the same company. FN_NORMALIZE_MFR resolves them.' },
    { id: 3, title: 'Missing identity keys', blurb: 'Not every device has an FDA DI. Some site entries lack model numbers. The matcher degrades gracefully: exact model, fuzzy model, description match.' },
    { id: 4, title: 'Acquisition name changes', blurb: '"Toshiba" is now Canon Medical. "Covidien" is now Medtronic. "CareFusion" is now BD. "Maquet" is now Getinge. The ontology maps legacy names.' },
    { id: 5, title: 'Model number formatting', blurb: 'FDA includes revision suffixes (B650 v2, A500 SW 3.0). TriMedx uses short codes (B650, A500). Site uses whatever the tech typed. FN_NORMALIZE_MODEL strips the noise.' },
    { id: 6, title: 'Overloaded inventory rows', blurb: 'Each EQUIPMENT_LIST row is a device + location + service history + condition. The ontology decomposes it into SiteEquipment + Department + Device links.' },
    { id: 7, title: 'Unmatched devices = unpriced risk', blurb: 'Every device that fails matching has no cost estimate. The quote underestimates the fleet. The ontology quantifies this gap explicitly.' },
];

export function getOverview() {
    const graph = getOntology();
    return {
        sourceSystems: SOURCE_SYSTEMS.length,
        sourceTables: SOURCE_SYSTEMS.reduce((n, s) => n + s.tables.length, 0),
        classes: graph.nodes.length,
        relationships: graph.links.length,
        challenges: CHALLENGES,
    };
}
