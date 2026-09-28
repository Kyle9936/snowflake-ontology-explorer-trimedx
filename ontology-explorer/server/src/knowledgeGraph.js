/**
 * Instance-level knowledge graph builder for the MMD demo.
 *
 * Unlike ontology.js (which describes the *classes*), this assembles a graph of
 * the ACTUAL DATA: real devices resolved and stitched across the three source
 * systems (FDA + TriMedx + Site Inventory) into one connected graph.
 *
 * Entity resolution:
 *   - TriMedx <-> FDA : DEVICE_CATALOG.FDA_DI = DEVICE_RECORD.GUDID_DI
 *   - Site <-> TriMedx: degrading hierarchy via FN_NORMALIZE_MFR + model matching
 *   - Manufacturer    : FN_NORMALIZE_MFR resolves all name variants to canonical
 *
 * "Hub" nodes (Manufacturer, DeviceFamily) are SHARED, so different devices
 * connect through the same manufacturer / family - showing the value of unification.
 */

import { query } from './snowflake.js';
import { GROUPS } from './ontology.js';
import { EHR, CLAIMS, RX, ONTOLOGY } from './dbconfig.js';

const CLASS_GROUP = {
    Device: 'device',
    Manufacturer: 'device',
    DeviceFamily: 'operations',
    SiteEquipment: 'place',
    ServiceCost: 'financial',
    MaintenanceSchedule: 'operations',
    FDARecord: 'regulatory',
    Site: 'place',
    Department: 'place',
};
const colorFor = (cls) => GROUPS[CLASS_GROUP[cls]]?.color || '#8595a6';

const inList = (arr) => {
    const vals = [...new Set(arr.filter((v) => v != null && v !== ''))];
    if (!vals.length) return `''`;
    return vals.map((v) => `'${String(v).replace(/'/g, "''")}'`).join(',');
};

/**
 * Build the instance graph for the first `limit` devices (ordered by CATALOG_ID).
 * Returns { nodes, links, groups, stats }.
 */
export async function getKnowledgeGraph(limit) {
    const n = Math.max(1, Math.min(Number(limit) || 10, 100));

    // 1. Anchor on canonical devices from TriMedx catalog.
    const devices = await query(`
        SELECT c.CATALOG_ID, c.MODEL_NUMBER, c.DEVICE_NAME, c.DEVICE_DESC,
               c.FDA_DI, c.FDA_CLASS, c.FAMILY_ID, c.STATUS,
               m.MFR_ID, m.MFR_NAME, m.MFR_FULL_NAME
        FROM ${CLAIMS}.DEVICE_CATALOG c
        JOIN ${CLAIMS}.MANUFACTURER m ON m.MFR_ID = c.MFR_ID
        WHERE c.STATUS IN ('ACTIVE', 'LEGACY')
        ORDER BY c.CATALOG_ID
        LIMIT ${n}
    `);

    if (!devices.length) return { nodes: [], links: [], groups: GROUPS, stats: {} };

    const catalogIds = devices.map((d) => d.CATALOG_ID);
    const fdaDis = devices.map((d) => d.FDA_DI).filter(Boolean);
    const mfrIds = [...new Set(devices.map((d) => d.MFR_ID))];
    const familyIds = [...new Set(devices.map((d) => d.FAMILY_ID).filter(Boolean))];

    // 2. Fetch related entities in parallel.
    const [fdaRecords, families, costs, pmSchedules, siteEquipment, depts, sites] = await Promise.all([
        fdaDis.length ? query(`
            SELECT GUDID_DI, COMPANY_NAME, BRAND_NAME, VERSION_MODEL_NUMBER, DEVICE_CLASS, PRODUCT_CODE
            FROM ${EHR}.DEVICE_RECORD WHERE GUDID_DI IN (${inList(fdaDis)})
        `) : [],
        familyIds.length ? query(`
            SELECT FAMILY_ID, FAMILY_NAME, FAMILY_CATEGORY, AVG_USEFUL_LIFE_YEARS
            FROM ${CLAIMS}.DEVICE_FAMILY WHERE FAMILY_ID IN (${inList(familyIds)})
        `) : [],
        query(`
            SELECT COST_ID, CATALOG_ID, ANNUAL_PARTS_COST, ANNUAL_LABOR_COST, ANNUAL_TOTAL_COST, RISK_TIER
            FROM ${CLAIMS}.SERVICE_COST_ESTIMATE WHERE CATALOG_ID IN (${inList(catalogIds)})
        `),
        familyIds.length ? query(`
            SELECT PM_ID, FAMILY_ID, PM_TYPE, INTERVAL_MONTHS, EST_LABOR_HOURS
            FROM ${CLAIMS}.PM_SCHEDULE WHERE FAMILY_ID IN (${inList(familyIds)})
        `) : [],
        query(`
            SELECT se.EQUIP_ID, se.MANUFACTURER AS RAW_MFR, se.MODEL AS RAW_MODEL,
                   se.DEVICE_DESCRIPTION AS RAW_DESC, se.SERIAL_NUMBER, se.DEPT_ID,
                   se.CONDITION, se.STATUS,
                   sm.CATALOG_ID AS RESOLVED_CATALOG_ID, sm.MATCH_BASIS
            FROM ${RX}.EQUIPMENT_LIST se
            JOIN ${ONTOLOGY}.STG_MAP_SITE_TO_CATALOG sm ON sm.EQUIP_ID = se.EQUIP_ID
            WHERE sm.CATALOG_ID IN (${inList(catalogIds)})
            ORDER BY se.EQUIP_ID
        `),
        query(`SELECT DEPT_ID, DEPT_NAME, FLOOR, WING, SITE_ID FROM ${RX}.DEPARTMENT`),
        query(`SELECT SITE_ID, SITE_NAME, SITE_TYPE, BED_COUNT FROM ${RX}.SITE_INFO`),
    ]);

    // 3. Build graph nodes + links.
    const nodes = [];
    const links = [];
    const nodeIds = new Set();

    const addNode = (id, cls, label, detail) => {
        if (nodeIds.has(id)) return;
        nodeIds.add(id);
        nodes.push({ id, label, group: CLASS_GROUP[cls], color: colorFor(cls), cls, detail });
    };

    const addLink = (src, tgt, label) => {
        if (!nodeIds.has(src) || !nodeIds.has(tgt)) return;
        links.push({ source: src, target: tgt, label });
    };

    // Manufacturers (hub nodes)
    const mfrMap = {};
    devices.forEach((d) => {
        const mfrNodeId = `MFR:${d.MFR_ID}`;
        mfrMap[d.MFR_ID] = mfrNodeId;
        addNode(mfrNodeId, 'Manufacturer', d.MFR_NAME, `${d.MFR_FULL_NAME}`);
    });

    // Device families (hub nodes)
    const famMap = {};
    families.forEach((f) => {
        const famNodeId = `FAM:${f.FAMILY_ID}`;
        famMap[f.FAMILY_ID] = famNodeId;
        addNode(famNodeId, 'DeviceFamily', f.FAMILY_NAME, `${f.FAMILY_CATEGORY} | Life: ${f.AVG_USEFUL_LIFE_YEARS}yr`);
    });

    // Sites
    sites.forEach((s) => {
        addNode(`SITE:${s.SITE_ID}`, 'Site', s.SITE_NAME, `${s.SITE_TYPE} | ${s.BED_COUNT} beds`);
    });

    // Departments
    const deptSiteMap = {};
    depts.forEach((d) => {
        const deptNodeId = `DEPT:${d.DEPT_ID}`;
        addNode(deptNodeId, 'Department', d.DEPT_NAME, `Floor ${d.FLOOR} ${d.WING}`);
        deptSiteMap[d.DEPT_ID] = d.SITE_ID;
        addLink(deptNodeId, `SITE:${d.SITE_ID}`, 'part_of_site');
    });

    // Devices
    devices.forEach((d) => {
        const devNodeId = `DEV:${d.CATALOG_ID}`;
        addNode(devNodeId, 'Device', d.DEVICE_NAME, `${d.MFR_NAME} ${d.MODEL_NUMBER} | ${d.DEVICE_DESC}`);
        // made_by
        if (mfrMap[d.MFR_ID]) addLink(devNodeId, mfrMap[d.MFR_ID], 'made_by');
        // belongs_to_family
        if (d.FAMILY_ID && famMap[d.FAMILY_ID]) addLink(devNodeId, famMap[d.FAMILY_ID], 'belongs_to_family');
    });

    // FDA records
    fdaRecords.forEach((f) => {
        const fdaNodeId = `FDA:${f.GUDID_DI}`;
        addNode(fdaNodeId, 'FDARecord', f.BRAND_NAME, `${f.COMPANY_NAME} | Class ${f.DEVICE_CLASS} | ${f.PRODUCT_CODE}`);
    });
    devices.forEach((d) => {
        if (d.FDA_DI) addLink(`DEV:${d.CATALOG_ID}`, `FDA:${d.FDA_DI}`, 'has_fda_record');
    });

    // Service costs
    costs.forEach((c) => {
        const costNodeId = `COST:${c.COST_ID}`;
        addNode(costNodeId, 'ServiceCost', `$${Number(c.ANNUAL_TOTAL_COST).toLocaleString()}/yr`, `Parts $${c.ANNUAL_PARTS_COST} | Labor $${c.ANNUAL_LABOR_COST} | ${c.RISK_TIER} risk`);
        addLink(`DEV:${c.CATALOG_ID}`, costNodeId, 'has_cost');
    });

    // PM schedules
    pmSchedules.forEach((p) => {
        const pmNodeId = `PM:${p.PM_ID}`;
        addNode(pmNodeId, 'MaintenanceSchedule', `${p.PM_TYPE}`, `Every ${p.INTERVAL_MONTHS}mo | ${p.EST_LABOR_HOURS}hr labor`);
        if (famMap[p.FAMILY_ID]) addLink(famMap[p.FAMILY_ID], pmNodeId, 'has_pm_schedule');
    });

    // Site equipment (the raw inventory items)
    siteEquipment.forEach((se) => {
        const seNodeId = `SE:${se.EQUIP_ID}`;
        const matchInfo = se.RESOLVED_CATALOG_ID ? ` [${se.MATCH_BASIS}]` : ' [UNMATCHED]';
        addNode(seNodeId, 'SiteEquipment', `${se.RAW_MFR} ${se.RAW_MODEL}`, `${se.RAW_DESC} | ${se.CONDITION}${matchInfo}`);
        // matched_to
        if (se.RESOLVED_CATALOG_ID) addLink(seNodeId, `DEV:${se.RESOLVED_CATALOG_ID}`, 'matched_to');
        // located_in
        if (se.DEPT_ID) addLink(seNodeId, `DEPT:${se.DEPT_ID}`, 'located_in');
    });

    // 4. Compute degree for each node (used for sizing in the frontend).
    const degreeMap = new Map();
    links.forEach((l) => {
        degreeMap.set(l.source, (degreeMap.get(l.source) || 0) + 1);
        degreeMap.set(l.target, (degreeMap.get(l.target) || 0) + 1);
    });
    nodes.forEach((n) => { n.degree = degreeMap.get(n.id) || 0; });

    // 5. Stats
    const matched = siteEquipment.filter((se) => se.RESOLVED_CATALOG_ID != null).length;
    const total = siteEquipment.length;
    const totalCost = costs.reduce((sum, c) => sum + Number(c.ANNUAL_TOTAL_COST || 0), 0);

    return {
        nodes,
        links,
        groups: GROUPS,
        stats: {
            devices: devices.length,
            siteEquipment: total,
            matched,
            unmatched: total - matched,
            matchRate: total > 0 ? `${((matched / total) * 100).toFixed(1)}%` : 'N/A',
            totalAnnualCost: `$${totalCost.toLocaleString()}`,
            manufacturers: mfrIds.length,
            families: families.length,
            nodes: nodes.length,
            links: links.length,
        },
    };
}
