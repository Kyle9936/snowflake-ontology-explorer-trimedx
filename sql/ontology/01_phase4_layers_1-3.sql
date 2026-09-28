-- =============================================================================
-- PHASE 4 - Ontology Layers 1-3 (+ inference, graph tools, provenance)
-- MMD_ONTOLOGY  .  target: FDA_DEVICES.ONTOLOGY  .  build role: SYSADMIN
-- =============================================================================
-- Adapted from the healthcare ontology explorer for the TriMedx MMD matching
-- use case. Sources span three databases (read): FDA_DEVICES.GUDID,
-- TRIMEDX_MMD.MASTER, SITE_INVENTORY.RAW. All ontology objects are created in
-- FDA_DEVICES.ONTOLOGY.
--
-- The core entity resolution problem: the same medical device appears under
-- different names, model numbers, and manufacturer labels across FDA, TriMedx,
-- and incoming site inventories. The ontology resolves them into canonical
-- Device nodes linked to maintenance costs, parts, and PM schedules.
-- =============================================================================



-- =============================================================================
-- >>> Layer 1 - Physical KG tables, canonicalization UDFs, cross-system
-- >>> resolution staging views, and KG load
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS FDA_DEVICES.ONTOLOGY;
USE SCHEMA FDA_DEVICES.ONTOLOGY;

-- ---- KG storage ------------------------------------------------------------
CREATE OR REPLACE TABLE KG_NODE (
    NODE_ID      STRING NOT NULL,
    NODE_TYPE    STRING NOT NULL,
    NAME         STRING,
    PROPS        VARIANT,
    TS_INGESTED  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KG_NODE PRIMARY KEY (NODE_ID)
) CLUSTER BY (NODE_TYPE);

CREATE OR REPLACE TABLE KG_EDGE (
    EDGE_ID         STRING NOT NULL,
    SRC_ID          STRING NOT NULL,
    DST_ID          STRING NOT NULL,
    EDGE_TYPE       STRING NOT NULL,
    WEIGHT          FLOAT DEFAULT 1.0,
    PROPS           VARIANT,
    EFFECTIVE_START DATE,
    EFFECTIVE_END   DATE,
    TS_INGESTED     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KG_EDGE PRIMARY KEY (EDGE_ID)
) CLUSTER BY (EDGE_TYPE, SRC_ID, DST_ID);

-- ---- Canonicalization helper: normalize manufacturer name ------------------
CREATE OR REPLACE FUNCTION FN_NORMALIZE_MFR(raw_name STRING)
RETURNS STRING
AS $$
  CASE
    WHEN raw_name IS NULL THEN NULL
    -- GE variants
    WHEN UPPER(TRIM(raw_name)) IN ('GE','G.E.','GE HEALTHCARE','GE MEDICAL SYSTEMS','GENERAL ELECTRIC CO','GENERAL ELECTRIC','GE MED SYS','GEN ELECTRIC','GE HEALTHCARE SYSTEMS') THEN 'GE Healthcare'
    -- Philips variants
    WHEN UPPER(TRIM(raw_name)) IN ('PHIL','PHIL MEDICAL','PHILIPS','PHILIPS MEDICAL SYSTEMS','PHILIPS HEALTHCARE','KONINKLIJKE PHILIPS N.V.','KONINKLIJKE PHILIPS NV') THEN 'Philips'
    -- Siemens variants
    WHEN UPPER(TRIM(raw_name)) IN ('SIEMENS','SIEMENS HEALTHINEERS','SIEMENS HEALTHINEERS AG','SIEMENS MEDICAL SOLUTIONS USA') THEN 'Siemens Healthineers'
    -- Medtronic / Covidien variants
    WHEN UPPER(TRIM(raw_name)) IN ('MEDTRONIC','MEDTRONIC, INC.','MEDTRONIC INC','MEDTRONIC PLC','COVIDIEN','COVIDIEN LLC') THEN 'Medtronic'
    -- Stryker variants
    WHEN UPPER(TRIM(raw_name)) IN ('STRYKER','STRYKER CORPORATION','STRYKER INSTRUMENTS','HOWMEDICA OSTEONICS CORP','HOWMEDICA') THEN 'Stryker'
    -- Baxter variants
    WHEN UPPER(TRIM(raw_name)) IN ('BAXTER','BAXTER INTERNATIONAL INC','BAXTER INTERNATIONAL','BAXTER HEALTHCARE CORPORATION','BAXTER HEALTHCARE') THEN 'Baxter'
    -- Draeger variants
    WHEN UPPER(TRIM(raw_name)) IN ('DRAEGER','DRAGER','DRAEGER MEDICAL','DRAGER MEDICAL','DRAEGER MEDICAL INC','DRAGER MEDICAL INC','DRAEGERWERK AG','DRAEGERWERK','DRAGERWERK AG') THEN 'Draeger'
    -- BD variants
    WHEN UPPER(TRIM(raw_name)) IN ('BD','BECTON DICKINSON','BECTON DICKINSON AND COMPANY','CAREFUSION','CAREFUSION CORPORATION') THEN 'BD'
    -- Hill-Rom variants
    WHEN UPPER(TRIM(raw_name)) IN ('HILL-ROM','HILLROM','HILL-ROM HOLDINGS INC','HILL-ROM HOLDINGS','WELCH ALLYN','WELCH ALLYN INC') THEN 'Hill-Rom'
    -- Canon / Toshiba variants
    WHEN UPPER(TRIM(raw_name)) IN ('CANON','CANON MEDICAL','CANON MEDICAL SYSTEMS CORPORATION','CANON MEDICAL SYSTEMS','TOSHIBA','TOSHIBA MEDICAL','TOSHIBA MEDICAL SYSTEMS CORPORATION','TOSHIBA MEDICAL SYSTEMS') THEN 'Canon Medical'
    -- Getinge / Maquet variants
    WHEN UPPER(TRIM(raw_name)) IN ('GETINGE','GETINGE AB','MAQUET','MAQUET MEDICAL SYSTEMS','MAQUET MEDICAL') THEN 'Getinge'
    -- Smith+Nephew variants
    WHEN UPPER(TRIM(raw_name)) IN ('SMITH & NEPHEW','SMITH AND NEPHEW','SMITH+NEPHEW','SMITH NEPHEW','SMITH & NEPHEW PLC','SMITH AND NEPHEW INC') THEN 'Smith+Nephew'
    -- Olympus variants
    WHEN UPPER(TRIM(raw_name)) IN ('OLYMPUS','OLYMPUS CORPORATION OF THE AMERICAS','OLYMPUS MEDICAL SYSTEMS CORP','OLYMPUS MEDICAL') THEN 'Olympus'
    -- Fujifilm variants
    WHEN UPPER(TRIM(raw_name)) IN ('FUJIFILM','FUJI','FUJIFILM HEALTHCARE AMERICAS','FUJIFILM HEALTHCARE','FUJIFILM MEDICAL SYSTEMS USA','FUJIFILM MEDICAL') THEN 'Fujifilm'
    -- Vyaire / CareFusion ventilator line
    WHEN UPPER(TRIM(raw_name)) IN ('VYAIRE','VYAIRE MEDICAL','VYAIRE MEDICAL INC') THEN 'Vyaire'
    -- Mindray variants
    WHEN UPPER(TRIM(raw_name)) IN ('MINDRAY','MINDRAY DS USA INC','MINDRAY DS USA','SHENZHEN MINDRAY BIO-MEDICAL','SHENZHEN MINDRAY') THEN 'Mindray'
    -- Steris variants
    WHEN UPPER(TRIM(raw_name)) IN ('STERIS','STERIS PLC','STERIS CORPORATION') THEN 'Steris'
    -- Masimo (handle typo "Masiom")
    WHEN UPPER(TRIM(raw_name)) IN ('MASIMO','MASIMO CORPORATION','MASIOM') THEN 'Masimo'
    -- Direct pass-through for already-clean names
    ELSE INITCAP(TRIM(raw_name))
  END
$$;

-- ---- Canonicalization helper: normalize model number ----------------------
CREATE OR REPLACE FUNCTION FN_NORMALIZE_MODEL(raw_model STRING)
RETURNS STRING
AS $$
  -- Strip common noise: leading/trailing spaces, "v2", "Rev B", "v3.0", etc.
  REGEXP_REPLACE(
    REGEXP_REPLACE(
      UPPER(TRIM(raw_model)),
      '\\s*(V[0-9]+\\.?[0-9]*|REV\\s*[A-Z0-9]+|SW\\s*[0-9]+\\.?[0-9]*|BT[0-9]+|GEN\\s*[0-9]+)\\s*$', ''
    ),
    '\\s+', ' '
  )
$$;

-- ============================================================================
-- STAGING / RESOLUTION VIEWS  (identity crosswalks)
-- ============================================================================

-- FDA GUDID -> TriMedx catalog (strong: direct FDA_DI match)
CREATE OR REPLACE VIEW STG_MAP_FDA_TO_CATALOG AS
SELECT
    f.GUDID_DI,
    c.CATALOG_ID,
    c.MODEL_NUMBER      AS TMX_MODEL,
    c.DEVICE_NAME       AS TMX_DEVICE_NAME,
    c.FAMILY_ID,
    'FDA_DI' AS MATCH_BASIS
FROM FDA_DEVICES.GUDID.DEVICE_RECORD f
JOIN TRIMEDX_MMD.MASTER.DEVICE_CATALOG c ON c.FDA_DI = f.GUDID_DI;

-- Site inventory -> TriMedx catalog (degrading hierarchy: model exact -> mfr+model fuzzy -> mfr+desc fuzzy)
CREATE OR REPLACE VIEW STG_MAP_SITE_TO_CATALOG AS
WITH normalized_site AS (
    SELECT
        e.EQUIP_ID,
        e.MANUFACTURER       AS RAW_MFR,
        e.MODEL               AS RAW_MODEL,
        e.DEVICE_DESCRIPTION  AS RAW_DESC,
        FN_NORMALIZE_MFR(e.MANUFACTURER) AS NORM_MFR,
        FN_NORMALIZE_MODEL(e.MODEL)      AS NORM_MODEL
    FROM SITE_INVENTORY.RAW.EQUIPMENT_LIST e
    WHERE e.STATUS != 'DECOMMISSIONED'
),
normalized_catalog AS (
    SELECT
        c.CATALOG_ID,
        c.MFR_ID,
        m.MFR_NAME            AS TMX_MFR_SHORT,
        FN_NORMALIZE_MFR(m.MFR_FULL_NAME) AS NORM_MFR,
        c.MODEL_NUMBER,
        FN_NORMALIZE_MODEL(c.MODEL_NUMBER) AS NORM_MODEL,
        c.DEVICE_NAME,
        c.DEVICE_DESC,
        c.FAMILY_ID
    FROM TRIMEDX_MMD.MASTER.DEVICE_CATALOG c
    JOIN TRIMEDX_MMD.MASTER.MANUFACTURER m ON m.MFR_ID = c.MFR_ID
    WHERE c.STATUS IN ('ACTIVE','LEGACY')
),
-- Pass 1: exact normalized manufacturer + exact normalized model
match_exact AS (
    SELECT
        s.EQUIP_ID,
        nc.CATALOG_ID,
        'EXACT_MODEL' AS MATCH_BASIS,
        1 AS MATCH_RANK
    FROM normalized_site s
    JOIN normalized_catalog nc
      ON s.NORM_MFR = nc.NORM_MFR
     AND s.NORM_MODEL = nc.NORM_MODEL
),
-- Pass 2: normalized manufacturer + model contained in site model string (or vice versa)
match_fuzzy_model AS (
    SELECT
        s.EQUIP_ID,
        nc.CATALOG_ID,
        'FUZZY_MODEL' AS MATCH_BASIS,
        2 AS MATCH_RANK
    FROM normalized_site s
    JOIN normalized_catalog nc
      ON s.NORM_MFR = nc.NORM_MFR
     AND (   CONTAINS(s.NORM_MODEL, nc.NORM_MODEL)
          OR CONTAINS(nc.NORM_MODEL, s.NORM_MODEL)
          OR CONTAINS(UPPER(s.RAW_MODEL), UPPER(nc.DEVICE_NAME))
          OR CONTAINS(UPPER(nc.DEVICE_NAME), UPPER(s.RAW_MODEL)) )
     AND s.EQUIP_ID NOT IN (SELECT EQUIP_ID FROM match_exact)
),
-- Pass 3: manufacturer match + description keyword overlap (weakest)
match_desc AS (
    SELECT
        s.EQUIP_ID,
        nc.CATALOG_ID,
        'DESC_MATCH' AS MATCH_BASIS,
        3 AS MATCH_RANK
    FROM normalized_site s
    JOIN normalized_catalog nc
      ON s.NORM_MFR = nc.NORM_MFR
     AND (   CONTAINS(UPPER(s.RAW_DESC), UPPER(nc.DEVICE_NAME))
          OR CONTAINS(UPPER(nc.DEVICE_DESC), UPPER(SPLIT_PART(s.RAW_DESC,' ',1)))  )
     AND s.EQUIP_ID NOT IN (SELECT EQUIP_ID FROM match_exact)
     AND s.EQUIP_ID NOT IN (SELECT EQUIP_ID FROM match_fuzzy_model)
),
all_matches AS (
    SELECT * FROM match_exact
    UNION ALL SELECT * FROM match_fuzzy_model
    UNION ALL SELECT * FROM match_desc
)
SELECT EQUIP_ID, CATALOG_ID, MATCH_BASIS, MATCH_RANK
FROM all_matches
QUALIFY ROW_NUMBER() OVER (PARTITION BY EQUIP_ID ORDER BY MATCH_RANK, CATALOG_ID) = 1;

-- Site inventory -> FDA (via resolved catalog's FDA_DI)
CREATE OR REPLACE VIEW STG_MAP_SITE_TO_FDA AS
SELECT
    sm.EQUIP_ID,
    c.FDA_DI         AS GUDID_DI,
    sm.CATALOG_ID,
    sm.MATCH_BASIS   AS SITE_MATCH_BASIS
FROM STG_MAP_SITE_TO_CATALOG sm
JOIN TRIMEDX_MMD.MASTER.DEVICE_CATALOG c ON c.CATALOG_ID = sm.CATALOG_ID
WHERE c.FDA_DI IS NOT NULL;

-- Canonical device (anchored on TriMedx CATALOG_ID, enriched with FDA + site presence)
CREATE OR REPLACE VIEW STG_DEVICE AS
SELECT
    c.CATALOG_ID                               AS DEVICE_KEY,
    c.CATALOG_ID,
    c.MODEL_NUMBER                             AS TMX_MODEL,
    c.DEVICE_NAME,
    c.DEVICE_DESC                              AS TMX_DESC,
    c.FDA_DI,
    c.FDA_CLASS,
    c.FAMILY_ID,
    c.STATUS                                   AS CATALOG_STATUS,
    m.MFR_ID,
    m.MFR_NAME                                 AS TMX_MFR_SHORT,
    FN_NORMALIZE_MFR(m.MFR_FULL_NAME)         AS CANONICAL_MFR,
    f.COMPANY_NAME                             AS FDA_MFR_NAME,
    f.VERSION_MODEL_NUMBER                     AS FDA_MODEL,
    f.BRAND_NAME                               AS FDA_BRAND,
    f.DEVICE_DESCRIPTION                       AS FDA_DESC,
    f.PRODUCT_CODE                             AS FDA_PRODUCT_CODE,
    df.FAMILY_NAME,
    df.FAMILY_CATEGORY,
    'TRIMEDX'
      || IFF(c.FDA_DI IS NOT NULL, ',FDA','')
      || IFF(EXISTS(SELECT 1 FROM STG_MAP_SITE_TO_CATALOG sc WHERE sc.CATALOG_ID = c.CATALOG_ID), ',SITE','')
                                               AS SOURCE_SYSTEMS
FROM TRIMEDX_MMD.MASTER.DEVICE_CATALOG c
JOIN TRIMEDX_MMD.MASTER.MANUFACTURER m ON m.MFR_ID = c.MFR_ID
LEFT JOIN FDA_DEVICES.GUDID.DEVICE_RECORD f ON f.GUDID_DI = c.FDA_DI
LEFT JOIN TRIMEDX_MMD.MASTER.DEVICE_FAMILY df ON df.FAMILY_ID = c.FAMILY_ID;

-- Canonical manufacturer
CREATE OR REPLACE VIEW STG_MANUFACTURER AS
SELECT
    m.MFR_ID,
    m.MFR_NAME                                 AS MFR_SHORT,
    m.MFR_FULL_NAME,
    FN_NORMALIZE_MFR(m.MFR_FULL_NAME)         AS CANONICAL_NAME,
    m.MFR_COUNTRY,
    -- Collect all FDA name variants for this manufacturer
    LISTAGG(DISTINCT f.COMPANY_NAME, ' | ') WITHIN GROUP (ORDER BY f.COMPANY_NAME) AS FDA_NAME_VARIANTS,
    COUNT(DISTINCT c.CATALOG_ID)               AS DEVICE_COUNT
FROM TRIMEDX_MMD.MASTER.MANUFACTURER m
LEFT JOIN TRIMEDX_MMD.MASTER.DEVICE_CATALOG c ON c.MFR_ID = m.MFR_ID
LEFT JOIN FDA_DEVICES.GUDID.DEVICE_RECORD f ON f.GUDID_DI = c.FDA_DI
WHERE m.ACTIVE_FLAG = TRUE
GROUP BY m.MFR_ID, m.MFR_NAME, m.MFR_FULL_NAME, m.MFR_COUNTRY;

-- Site equipment with resolution status
CREATE OR REPLACE VIEW STG_SITE_EQUIPMENT AS
SELECT
    e.EQUIP_ID,
    e.SITE_ID,
    e.DEPT_ID,
    e.MANUFACTURER       AS RAW_MFR,
    e.MODEL               AS RAW_MODEL,
    e.DEVICE_DESCRIPTION  AS RAW_DESC,
    e.SERIAL_NUMBER,
    e.ASSET_TAG,
    e.INSTALL_DATE,
    e.LAST_PM_DATE,
    e.CONDITION,
    e.STATUS,
    FN_NORMALIZE_MFR(e.MANUFACTURER) AS NORM_MFR,
    sm.CATALOG_ID         AS RESOLVED_CATALOG_ID,
    sm.MATCH_BASIS,
    IFF(sm.CATALOG_ID IS NOT NULL, TRUE, FALSE) AS IS_MATCHED
FROM SITE_INVENTORY.RAW.EQUIPMENT_LIST e
LEFT JOIN STG_MAP_SITE_TO_CATALOG sm ON sm.EQUIP_ID = e.EQUIP_ID;

-- ============================================================================
-- KG_NODE LOADS  (one canonical node per resolved entity)
-- ============================================================================

-- Device (canonical, anchored on TriMedx CATALOG_ID)
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'DEV:'||DEVICE_KEY, 'Device', DEVICE_NAME,
  OBJECT_CONSTRUCT(
    'catalog_id',CATALOG_ID,'tmx_model',TMX_MODEL,'device_name',DEVICE_NAME,'tmx_desc',TMX_DESC,
    'fda_di',FDA_DI,'fda_class',FDA_CLASS,'family_id',FAMILY_ID,'catalog_status',CATALOG_STATUS,
    'mfr_id',MFR_ID,'canonical_mfr',CANONICAL_MFR,'tmx_mfr_short',TMX_MFR_SHORT,
    'fda_mfr_name',FDA_MFR_NAME,'fda_model',FDA_MODEL,'fda_brand',FDA_BRAND,'fda_desc',FDA_DESC,
    'fda_product_code',FDA_PRODUCT_CODE,'family_name',FAMILY_NAME,'family_category',FAMILY_CATEGORY,
    'source_systems',SOURCE_SYSTEMS)
FROM STG_DEVICE;

-- Manufacturer
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'MFR:'||MFR_ID, 'Manufacturer', CANONICAL_NAME,
  OBJECT_CONSTRUCT(
    'mfr_id',MFR_ID,'mfr_short',MFR_SHORT,'mfr_full_name',MFR_FULL_NAME,
    'canonical_name',CANONICAL_NAME,'mfr_country',MFR_COUNTRY,
    'fda_name_variants',FDA_NAME_VARIANTS,'device_count',DEVICE_COUNT)
FROM STG_MANUFACTURER;

-- DeviceFamily
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'FAM:'||FAMILY_ID, 'DeviceFamily', FAMILY_NAME,
  OBJECT_CONSTRUCT(
    'family_id',FAMILY_ID,'family_name',FAMILY_NAME,'family_category',FAMILY_CATEGORY,
    'description',DESCRIPTION,'avg_useful_life_years',AVG_USEFUL_LIFE_YEARS)
FROM TRIMEDX_MMD.MASTER.DEVICE_FAMILY;

-- Site
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'SITE:'||SITE_ID, 'Site', SITE_NAME,
  OBJECT_CONSTRUCT(
    'site_id',SITE_ID,'site_name',SITE_NAME,'site_type',SITE_TYPE,'bed_count',BED_COUNT,
    'address',ADDRESS,'city',CITY,'state',STATE,'zip',ZIP,'onboard_date',TO_VARCHAR(ONBOARD_DATE))
FROM SITE_INVENTORY.RAW.SITE_INFO;

-- Department
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'DEPT:'||DEPT_ID, 'Department', DEPT_NAME,
  OBJECT_CONSTRUCT(
    'dept_id',DEPT_ID,'site_id',SITE_ID,'dept_name',DEPT_NAME,'floor',FLOOR,'wing',WING)
FROM SITE_INVENTORY.RAW.DEPARTMENT;

-- SiteEquipment (the raw inventory record - one node per physical device instance)
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'SE:'||EQUIP_ID, 'SiteEquipment', RAW_MFR||' '||RAW_MODEL,
  OBJECT_CONSTRUCT(
    'equip_id',EQUIP_ID,'site_id',SITE_ID,'dept_id',DEPT_ID,
    'raw_mfr',RAW_MFR,'raw_model',RAW_MODEL,'raw_desc',RAW_DESC,
    'serial_number',SERIAL_NUMBER,'asset_tag',ASSET_TAG,
    'install_date',TO_VARCHAR(INSTALL_DATE),'last_pm_date',TO_VARCHAR(LAST_PM_DATE),
    'condition',CONDITION,'status',STATUS,
    'norm_mfr',NORM_MFR,'resolved_catalog_id',RESOLVED_CATALOG_ID,
    'match_basis',MATCH_BASIS,'is_matched',IS_MATCHED)
FROM STG_SITE_EQUIPMENT;

-- MaintenanceSchedule (PM templates)
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'PM:'||PM_ID, 'MaintenanceSchedule', PM_TYPE||' - '||DESCRIPTION,
  OBJECT_CONSTRUCT(
    'pm_id',PM_ID,'family_id',FAMILY_ID,'pm_type',PM_TYPE,
    'interval_months',INTERVAL_MONTHS,'est_labor_hours',EST_LABOR_HOURS,
    'description',DESCRIPTION)
FROM TRIMEDX_MMD.MASTER.PM_SCHEDULE;

-- ServiceCost (annual cost estimates per device)
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'COST:'||COST_ID, 'ServiceCost', 'Annual cost: $'||ANNUAL_TOTAL_COST,
  OBJECT_CONSTRUCT(
    'cost_id',COST_ID,'catalog_id',CATALOG_ID,
    'annual_parts_cost',ANNUAL_PARTS_COST,'annual_labor_cost',ANNUAL_LABOR_COST,
    'annual_pm_cost',ANNUAL_PM_COST,'annual_total_cost',ANNUAL_TOTAL_COST,
    'risk_tier',RISK_TIER,'cost_confidence',COST_CONFIDENCE,
    'effective_date',TO_VARCHAR(EFFECTIVE_DATE))
FROM TRIMEDX_MMD.MASTER.SERVICE_COST_ESTIMATE;

-- FDARecord (raw FDA device record)
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'FDA:'||GUDID_DI, 'FDARecord', BRAND_NAME,
  OBJECT_CONSTRUCT(
    'gudid_di',GUDID_DI,'company_name',COMPANY_NAME,'brand_name',BRAND_NAME,
    'version_model_number',VERSION_MODEL_NUMBER,'catalog_number',CATALOG_NUMBER,
    'device_description',DEVICE_DESCRIPTION,'device_class',DEVICE_CLASS,
    'product_code',PRODUCT_CODE,'medical_specialty_code',MEDICAL_SPECIALTY_CODE,
    'device_status',DEVICE_STATUS,'publish_date',TO_VARCHAR(PUBLISH_DATE))
FROM FDA_DEVICES.GUDID.DEVICE_RECORD;

-- TBox: one node per ontology class (for hierarchy traversal UDFs)
INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS)
SELECT 'CLASS:'||c.class_name, 'OntologyClass', c.class_name,
  OBJECT_CONSTRUCT('class_name',c.class_name,'parent',c.parent,'is_abstract',c.is_abstract)
FROM (
  SELECT * FROM (VALUES
    ('Entity',NULL,TRUE),
    ('PhysicalThing','Entity',TRUE),('Organization','Entity',TRUE),('Place','Entity',TRUE),('Record','Entity',TRUE),
    ('Device','PhysicalThing',FALSE),('SiteEquipment','PhysicalThing',FALSE),
    ('Manufacturer','Organization',FALSE),
    ('DeviceFamily','Entity',FALSE),
    ('Site','Place',FALSE),('Department','Place',FALSE),
    ('FDARecord','Record',FALSE),('MaintenanceSchedule','Record',FALSE),('ServiceCost','Record',FALSE)
  ) AS t(class_name, parent, is_abstract)
) c;

-- ============================================================================
-- KG_EDGE LOADS
-- ============================================================================

-- subClassOf (TBox hierarchy)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:subClassOf:'||child, 'CLASS:'||child, 'CLASS:'||parent, 'subClassOf'
FROM (
  SELECT * FROM (VALUES
    ('PhysicalThing','Entity'),('Organization','Entity'),('Place','Entity'),('Record','Entity'),
    ('Device','PhysicalThing'),('SiteEquipment','PhysicalThing'),
    ('Manufacturer','Organization'),
    ('DeviceFamily','Entity'),
    ('Site','Place'),('Department','Place'),
    ('FDARecord','Record'),('MaintenanceSchedule','Record'),('ServiceCost','Record')
  ) AS t(child, parent)
);

-- device_made_by (Device -> Manufacturer)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:made_by:'||CATALOG_ID, 'DEV:'||CATALOG_ID, 'MFR:'||MFR_ID, 'made_by'
FROM TRIMEDX_MMD.MASTER.DEVICE_CATALOG;

-- device_belongs_to_family (Device -> DeviceFamily)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:belongs_to_family:'||CATALOG_ID, 'DEV:'||CATALOG_ID, 'FAM:'||FAMILY_ID, 'belongs_to_family'
FROM TRIMEDX_MMD.MASTER.DEVICE_CATALOG
WHERE FAMILY_ID IS NOT NULL;

-- device_has_fda_record (Device -> FDARecord)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:has_fda_record:'||CATALOG_ID, 'DEV:'||CATALOG_ID, 'FDA:'||FDA_DI, 'has_fda_record'
FROM TRIMEDX_MMD.MASTER.DEVICE_CATALOG
WHERE FDA_DI IS NOT NULL;

-- device_has_cost (Device -> ServiceCost)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:has_cost:'||COST_ID, 'DEV:'||CATALOG_ID, 'COST:'||COST_ID, 'has_cost'
FROM TRIMEDX_MMD.MASTER.SERVICE_COST_ESTIMATE;

-- family_has_pm (DeviceFamily -> MaintenanceSchedule)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:has_pm:'||PM_ID, 'FAM:'||FAMILY_ID, 'PM:'||PM_ID, 'has_pm_schedule'
FROM TRIMEDX_MMD.MASTER.PM_SCHEDULE;

-- site_equipment_matched_to (SiteEquipment -> Device, via resolution)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, PROPS)
SELECT 'E:matched_to:'||EQUIP_ID, 'SE:'||EQUIP_ID, 'DEV:'||RESOLVED_CATALOG_ID, 'matched_to',
  OBJECT_CONSTRUCT('match_basis',MATCH_BASIS)
FROM STG_SITE_EQUIPMENT
WHERE IS_MATCHED = TRUE;

-- site_equipment_located_in (SiteEquipment -> Department)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:located_in:'||EQUIP_ID, 'SE:'||EQUIP_ID, 'DEPT:'||DEPT_ID, 'located_in'
FROM SITE_INVENTORY.RAW.EQUIPMENT_LIST
WHERE DEPT_ID IS NOT NULL;

-- department_part_of_site (Department -> Site)
INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
SELECT 'E:part_of_site:'||DEPT_ID, 'DEPT:'||DEPT_ID, 'SITE:'||SITE_ID, 'part_of_site'
FROM SITE_INVENTORY.RAW.DEPARTMENT;



-- =============================================================================
-- >>> Layer 3 (concrete) - typed V_{CLASS} entity views and V_{REL} relationship
-- >>> views over KG_NODE/KG_EDGE
-- =============================================================================

-- ============================================================================
-- ENTITY VIEWS  (one per ontology class; project PROPS into typed columns)
-- ============================================================================

CREATE OR REPLACE VIEW V_DEVICE AS
SELECT
    NODE_ID, NAME AS DEVICE_NAME,
    PROPS:catalog_id::NUMBER         AS CATALOG_ID,
    PROPS:tmx_model::STRING          AS TMX_MODEL,
    PROPS:tmx_desc::STRING           AS TMX_DESC,
    PROPS:fda_di::STRING             AS FDA_DI,
    PROPS:fda_class::NUMBER          AS FDA_CLASS,
    PROPS:family_id::NUMBER          AS FAMILY_ID,
    PROPS:catalog_status::STRING     AS CATALOG_STATUS,
    PROPS:mfr_id::NUMBER             AS MFR_ID,
    PROPS:canonical_mfr::STRING      AS CANONICAL_MFR,
    PROPS:tmx_mfr_short::STRING      AS TMX_MFR_SHORT,
    PROPS:fda_mfr_name::STRING       AS FDA_MFR_NAME,
    PROPS:fda_model::STRING          AS FDA_MODEL,
    PROPS:fda_brand::STRING          AS FDA_BRAND,
    PROPS:fda_desc::STRING           AS FDA_DESC,
    PROPS:fda_product_code::STRING   AS FDA_PRODUCT_CODE,
    PROPS:family_name::STRING        AS FAMILY_NAME,
    PROPS:family_category::STRING    AS FAMILY_CATEGORY,
    PROPS:source_systems::STRING     AS SOURCE_SYSTEMS
FROM KG_NODE WHERE NODE_TYPE = 'Device';

CREATE OR REPLACE VIEW V_MANUFACTURER AS
SELECT
    NODE_ID, NAME AS MANUFACTURER_NAME,
    PROPS:mfr_id::NUMBER             AS MFR_ID,
    PROPS:mfr_short::STRING          AS MFR_SHORT,
    PROPS:mfr_full_name::STRING      AS MFR_FULL_NAME,
    PROPS:canonical_name::STRING     AS CANONICAL_NAME,
    PROPS:mfr_country::STRING        AS MFR_COUNTRY,
    PROPS:fda_name_variants::STRING  AS FDA_NAME_VARIANTS,
    PROPS:device_count::NUMBER       AS DEVICE_COUNT
FROM KG_NODE WHERE NODE_TYPE = 'Manufacturer';

CREATE OR REPLACE VIEW V_DEVICE_FAMILY AS
SELECT
    NODE_ID, NAME AS FAMILY_NAME,
    PROPS:family_id::NUMBER          AS FAMILY_ID,
    PROPS:family_category::STRING    AS FAMILY_CATEGORY,
    PROPS:description::STRING        AS DESCRIPTION,
    PROPS:avg_useful_life_years::NUMBER AS AVG_USEFUL_LIFE_YEARS
FROM KG_NODE WHERE NODE_TYPE = 'DeviceFamily';

CREATE OR REPLACE VIEW V_SITE AS
SELECT
    NODE_ID, NAME AS SITE_NAME,
    PROPS:site_id::NUMBER            AS SITE_ID,
    PROPS:site_type::STRING          AS SITE_TYPE,
    PROPS:bed_count::NUMBER          AS BED_COUNT,
    PROPS:address::STRING            AS ADDRESS,
    PROPS:city::STRING               AS CITY,
    PROPS:state::STRING              AS STATE,
    PROPS:zip::STRING                AS ZIP,
    PROPS:onboard_date::STRING       AS ONBOARD_DATE
FROM KG_NODE WHERE NODE_TYPE = 'Site';

CREATE OR REPLACE VIEW V_DEPARTMENT AS
SELECT
    NODE_ID, NAME AS DEPT_NAME,
    PROPS:dept_id::NUMBER            AS DEPT_ID,
    PROPS:site_id::NUMBER            AS SITE_ID,
    PROPS:floor::STRING              AS FLOOR,
    PROPS:wing::STRING               AS WING
FROM KG_NODE WHERE NODE_TYPE = 'Department';

CREATE OR REPLACE VIEW V_SITE_EQUIPMENT AS
SELECT
    NODE_ID, NAME AS EQUIPMENT_NAME,
    PROPS:equip_id::NUMBER           AS EQUIP_ID,
    PROPS:site_id::NUMBER            AS SITE_ID,
    PROPS:dept_id::NUMBER            AS DEPT_ID,
    PROPS:raw_mfr::STRING            AS RAW_MFR,
    PROPS:raw_model::STRING          AS RAW_MODEL,
    PROPS:raw_desc::STRING           AS RAW_DESC,
    PROPS:serial_number::STRING      AS SERIAL_NUMBER,
    PROPS:asset_tag::STRING          AS ASSET_TAG,
    PROPS:install_date::STRING       AS INSTALL_DATE,
    PROPS:last_pm_date::STRING       AS LAST_PM_DATE,
    PROPS:condition::STRING          AS CONDITION,
    PROPS:status::STRING             AS STATUS,
    PROPS:norm_mfr::STRING           AS NORM_MFR,
    PROPS:resolved_catalog_id::NUMBER AS RESOLVED_CATALOG_ID,
    PROPS:match_basis::STRING        AS MATCH_BASIS,
    PROPS:is_matched::BOOLEAN        AS IS_MATCHED
FROM KG_NODE WHERE NODE_TYPE = 'SiteEquipment';

CREATE OR REPLACE VIEW V_MAINTENANCE_SCHEDULE AS
SELECT
    NODE_ID, NAME AS PM_NAME,
    PROPS:pm_id::NUMBER              AS PM_ID,
    PROPS:family_id::NUMBER          AS FAMILY_ID,
    PROPS:pm_type::STRING            AS PM_TYPE,
    PROPS:interval_months::NUMBER    AS INTERVAL_MONTHS,
    PROPS:est_labor_hours::FLOAT     AS EST_LABOR_HOURS,
    PROPS:description::STRING        AS DESCRIPTION
FROM KG_NODE WHERE NODE_TYPE = 'MaintenanceSchedule';

CREATE OR REPLACE VIEW V_SERVICE_COST AS
SELECT
    NODE_ID, NAME AS COST_LABEL,
    PROPS:cost_id::NUMBER            AS COST_ID,
    PROPS:catalog_id::NUMBER         AS CATALOG_ID,
    PROPS:annual_parts_cost::FLOAT   AS ANNUAL_PARTS_COST,
    PROPS:annual_labor_cost::FLOAT   AS ANNUAL_LABOR_COST,
    PROPS:annual_pm_cost::FLOAT      AS ANNUAL_PM_COST,
    PROPS:annual_total_cost::FLOAT   AS ANNUAL_TOTAL_COST,
    PROPS:risk_tier::STRING          AS RISK_TIER,
    PROPS:cost_confidence::STRING    AS COST_CONFIDENCE,
    PROPS:effective_date::STRING     AS EFFECTIVE_DATE
FROM KG_NODE WHERE NODE_TYPE = 'ServiceCost';

CREATE OR REPLACE VIEW V_FDA_RECORD AS
SELECT
    NODE_ID, NAME AS FDA_BRAND_NAME,
    PROPS:gudid_di::STRING           AS GUDID_DI,
    PROPS:company_name::STRING       AS COMPANY_NAME,
    PROPS:brand_name::STRING         AS BRAND_NAME,
    PROPS:version_model_number::STRING AS VERSION_MODEL_NUMBER,
    PROPS:catalog_number::STRING     AS CATALOG_NUMBER,
    PROPS:device_description::STRING AS DEVICE_DESCRIPTION,
    PROPS:device_class::NUMBER       AS DEVICE_CLASS,
    PROPS:product_code::STRING       AS PRODUCT_CODE,
    PROPS:medical_specialty_code::STRING AS MEDICAL_SPECIALTY_CODE,
    PROPS:device_status::STRING      AS DEVICE_STATUS,
    PROPS:publish_date::STRING       AS PUBLISH_DATE
FROM KG_NODE WHERE NODE_TYPE = 'FDARecord';

-- ============================================================================
-- RELATIONSHIP VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW V_REL_MADE_BY AS
SELECT e.EDGE_ID, e.SRC_ID AS DEVICE_NODE_ID, e.DST_ID AS MFR_NODE_ID,
       d.NAME AS DEVICE_NAME, m.NAME AS MANUFACTURER_NAME
FROM KG_EDGE e
JOIN KG_NODE d ON d.NODE_ID = e.SRC_ID
JOIN KG_NODE m ON m.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'made_by';

CREATE OR REPLACE VIEW V_REL_BELONGS_TO_FAMILY AS
SELECT e.EDGE_ID, e.SRC_ID AS DEVICE_NODE_ID, e.DST_ID AS FAMILY_NODE_ID,
       d.NAME AS DEVICE_NAME, f.NAME AS FAMILY_NAME
FROM KG_EDGE e
JOIN KG_NODE d ON d.NODE_ID = e.SRC_ID
JOIN KG_NODE f ON f.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'belongs_to_family';

CREATE OR REPLACE VIEW V_REL_HAS_FDA_RECORD AS
SELECT e.EDGE_ID, e.SRC_ID AS DEVICE_NODE_ID, e.DST_ID AS FDA_NODE_ID,
       d.NAME AS DEVICE_NAME, f.NAME AS FDA_BRAND_NAME
FROM KG_EDGE e
JOIN KG_NODE d ON d.NODE_ID = e.SRC_ID
JOIN KG_NODE f ON f.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'has_fda_record';

CREATE OR REPLACE VIEW V_REL_HAS_COST AS
SELECT e.EDGE_ID, e.SRC_ID AS DEVICE_NODE_ID, e.DST_ID AS COST_NODE_ID,
       d.NAME AS DEVICE_NAME, c.NAME AS COST_LABEL
FROM KG_EDGE e
JOIN KG_NODE d ON d.NODE_ID = e.SRC_ID
JOIN KG_NODE c ON c.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'has_cost';

CREATE OR REPLACE VIEW V_REL_HAS_PM AS
SELECT e.EDGE_ID, e.SRC_ID AS FAMILY_NODE_ID, e.DST_ID AS PM_NODE_ID,
       f.NAME AS FAMILY_NAME, p.NAME AS PM_NAME
FROM KG_EDGE e
JOIN KG_NODE f ON f.NODE_ID = e.SRC_ID
JOIN KG_NODE p ON p.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'has_pm_schedule';

CREATE OR REPLACE VIEW V_REL_MATCHED_TO AS
SELECT e.EDGE_ID, e.SRC_ID AS SITE_EQUIP_NODE_ID, e.DST_ID AS DEVICE_NODE_ID,
       se.NAME AS EQUIPMENT_NAME, d.NAME AS DEVICE_NAME,
       e.PROPS:match_basis::STRING AS MATCH_BASIS
FROM KG_EDGE e
JOIN KG_NODE se ON se.NODE_ID = e.SRC_ID
JOIN KG_NODE d  ON d.NODE_ID  = e.DST_ID
WHERE e.EDGE_TYPE = 'matched_to';

CREATE OR REPLACE VIEW V_REL_LOCATED_IN AS
SELECT e.EDGE_ID, e.SRC_ID AS SITE_EQUIP_NODE_ID, e.DST_ID AS DEPT_NODE_ID,
       se.NAME AS EQUIPMENT_NAME, dp.NAME AS DEPT_NAME
FROM KG_EDGE e
JOIN KG_NODE se ON se.NODE_ID = e.SRC_ID
JOIN KG_NODE dp ON dp.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'located_in';

CREATE OR REPLACE VIEW V_REL_PART_OF_SITE AS
SELECT e.EDGE_ID, e.SRC_ID AS DEPT_NODE_ID, e.DST_ID AS SITE_NODE_ID,
       dp.NAME AS DEPT_NAME, s.NAME AS SITE_NAME
FROM KG_EDGE e
JOIN KG_NODE dp ON dp.NODE_ID = e.SRC_ID
JOIN KG_NODE s  ON s.NODE_ID  = e.DST_ID
WHERE e.EDGE_TYPE = 'part_of_site';



-- =============================================================================
-- >>> Layer 2 - Ontology metadata tables (ONT_CLASS, ONT_RELATION_DEF, etc.)
-- =============================================================================

-- ============================================================================
-- ONTOLOGY METADATA TABLES  (self-describing ontology)
-- ============================================================================

CREATE OR REPLACE TABLE ONT_CLASS (
    CLASS_NAME      STRING NOT NULL PRIMARY KEY,
    PARENT_CLASS    STRING,
    IS_ABSTRACT     BOOLEAN DEFAULT FALSE,
    DESCRIPTION     STRING,
    DOMAIN_GROUP    STRING
);

INSERT INTO ONT_CLASS VALUES
('Entity',NULL,TRUE,'Root of all ontology classes','core'),
('PhysicalThing','Entity',TRUE,'Tangible object','core'),
('Organization','Entity',TRUE,'Business entity','core'),
('Place','Entity',TRUE,'Physical location','core'),
('Record','Entity',TRUE,'Administrative or regulatory record','core'),
('Device','PhysicalThing',FALSE,'Canonical medical device from TriMedx MMD catalog. Resolves naming variants across FDA, TriMedx, and site inventories into one identity.','device'),
('SiteEquipment','PhysicalThing',FALSE,'A physical device instance at a specific site. Raw inventory record before or after resolution to a canonical Device.','device'),
('Manufacturer','Organization',FALSE,'Device manufacturer. Resolves aliases (GE / GE Healthcare / General Electric) into one canonical name.','device'),
('DeviceFamily','Entity',FALSE,'Logical grouping of similar devices for pricing, PM scheduling, and fleet analysis.','operations'),
('Site','Place',FALSE,'A hospital or facility being onboarded for device management.','place'),
('Department','Place',FALSE,'A department or unit within a site where devices are installed.','place'),
('FDARecord','Record',FALSE,'FDA GUDID registry entry for a device. Contains regulatory classification and official device description.','regulatory'),
('MaintenanceSchedule','Record',FALSE,'Preventive maintenance template defining PM type, interval, and labor estimate for a device family.','operations'),
('ServiceCost','Record',FALSE,'Annual service cost estimate for a specific device model, including parts, labor, and PM costs.','financial');

CREATE OR REPLACE TABLE ONT_RELATION_DEF (
    RELATION_NAME   STRING NOT NULL PRIMARY KEY,
    SOURCE_CLASS    STRING,
    TARGET_CLASS    STRING,
    CARDINALITY     STRING,       -- 1:1 / 1:N / N:1 / N:M
    DESCRIPTION     STRING
);

INSERT INTO ONT_RELATION_DEF VALUES
('made_by','Device','Manufacturer','N:1','Device is manufactured by a Manufacturer'),
('belongs_to_family','Device','DeviceFamily','N:1','Device belongs to a logical DeviceFamily'),
('has_fda_record','Device','FDARecord','1:1','Device links to its FDA GUDID registry record'),
('has_cost','Device','ServiceCost','1:1','Device has an annual ServiceCost estimate'),
('has_pm_schedule','DeviceFamily','MaintenanceSchedule','1:N','DeviceFamily has one or more PM schedule templates'),
('matched_to','SiteEquipment','Device','N:1','Site inventory record resolved to a canonical Device via degrading-hierarchy matching'),
('located_in','SiteEquipment','Department','N:1','Site equipment is installed in a Department'),
('part_of_site','Department','Site','N:1','Department belongs to a Site'),
('subClassOf','OntologyClass','OntologyClass','N:1','Class hierarchy (ISA)');

CREATE OR REPLACE TABLE ONT_OBJECT_SOURCE (
    CLASS_NAME      STRING,
    SOURCE_SYSTEM   STRING,
    SOURCE_TABLE    STRING,
    SOURCE_COLUMNS  STRING,
    NOTES           STRING
);

INSERT INTO ONT_OBJECT_SOURCE VALUES
('Device','TRIMEDX_MMD','DEVICE_CATALOG','CATALOG_ID, MODEL_NUMBER, DEVICE_NAME, DEVICE_DESC, FDA_DI, FAMILY_ID','Canonical anchor; one row per known device model'),
('Device','FDA_DEVICES','DEVICE_RECORD','GUDID_DI, COMPANY_NAME, BRAND_NAME, VERSION_MODEL_NUMBER, DEVICE_DESCRIPTION','Enrichment via FDA_DI join; provides regulatory description and classification'),
('Manufacturer','TRIMEDX_MMD','MANUFACTURER','MFR_ID, MFR_NAME, MFR_FULL_NAME','TriMedx internal short names (GE, Phil, Siemens)'),
('Manufacturer','FDA_DEVICES','DEVICE_RECORD','COMPANY_NAME','FDA free-text names (GE Healthcare, General Electric Co, GE Medical Systems)'),
('Manufacturer','SITE_INVENTORY','EQUIPMENT_LIST','MANUFACTURER','Site free-text names (GE, G.E., Gen Electric, GE Med Sys, Phil, Drager)'),
('DeviceFamily','TRIMEDX_MMD','DEVICE_FAMILY','FAMILY_ID, FAMILY_NAME, FAMILY_CATEGORY','TriMedx-only concept; not in FDA or site data'),
('SiteEquipment','SITE_INVENTORY','EQUIPMENT_LIST','EQUIP_ID, MANUFACTURER, MODEL, DEVICE_DESCRIPTION, SERIAL_NUMBER','Raw incoming inventory; unstructured free-text fields'),
('Site','SITE_INVENTORY','SITE_INFO','SITE_ID, SITE_NAME, SITE_TYPE, BED_COUNT','One record per facility being onboarded'),
('Department','SITE_INVENTORY','DEPARTMENT','DEPT_ID, DEPT_NAME, FLOOR, WING','Departments within the site'),
('FDARecord','FDA_DEVICES','DEVICE_RECORD','GUDID_DI, COMPANY_NAME, BRAND_NAME, VERSION_MODEL_NUMBER, DEVICE_DESCRIPTION, DEVICE_CLASS, PRODUCT_CODE','Full FDA GUDID record'),
('MaintenanceSchedule','TRIMEDX_MMD','PM_SCHEDULE','PM_ID, FAMILY_ID, PM_TYPE, INTERVAL_MONTHS, EST_LABOR_HOURS','PM templates by device family'),
('ServiceCost','TRIMEDX_MMD','SERVICE_COST_ESTIMATE','COST_ID, CATALOG_ID, ANNUAL_PARTS_COST, ANNUAL_LABOR_COST, ANNUAL_TOTAL_COST','Annual cost per device model');

CREATE OR REPLACE TABLE ONT_IDENTITY_RULE (
    CLASS_NAME      STRING,
    RULE_ORDER      NUMBER,
    KEY_SYSTEM      STRING,
    KEY_DESCRIPTION STRING,
    CONFIDENCE      STRING        -- HIGH / MEDIUM / LOW
);

INSERT INTO ONT_IDENTITY_RULE VALUES
('Device',1,'FDA_DI','FDA Global Unique Device Identifier - direct match between TriMedx catalog and FDA registry','HIGH'),
('Device',2,'MFR+MODEL_EXACT','Normalized manufacturer name + exact normalized model number','HIGH'),
('Device',3,'MFR+MODEL_FUZZY','Normalized manufacturer + model substring/containment match','MEDIUM'),
('Device',4,'MFR+DESC_MATCH','Normalized manufacturer + device description keyword overlap','LOW'),
('Manufacturer',1,'MFR_ID','TriMedx internal manufacturer ID','HIGH'),
('Manufacturer',2,'NORMALIZED_NAME','FN_NORMALIZE_MFR() resolves all known aliases to one canonical name','HIGH'),
('SiteEquipment',1,'EQUIP_ID','Site-assigned equipment identifier - unique within a site inventory','HIGH');

CREATE OR REPLACE TABLE ONT_CLASS_MAP (
    SOURCE_SYSTEM   STRING,
    SOURCE_TABLE    STRING,
    SOURCE_LABEL    STRING,       -- what the source system calls it
    TARGET_CLASS    STRING,       -- ontology class
    NOTES           STRING
);

INSERT INTO ONT_CLASS_MAP VALUES
('FDA_DEVICES','DEVICE_RECORD','Device Record','FDARecord','One-to-one: each GUDID entry maps to one FDARecord node'),
('FDA_DEVICES','DEVICE_RECORD','COMPANY_NAME','Manufacturer','Many-to-one: multiple FDA name variants resolve to one Manufacturer'),
('TRIMEDX_MMD','DEVICE_CATALOG','Device Catalog Entry','Device','One-to-one: each catalog entry is one canonical Device'),
('TRIMEDX_MMD','MANUFACTURER','Manufacturer','Manufacturer','One-to-one: TriMedx manufacturer record'),
('TRIMEDX_MMD','DEVICE_FAMILY','Device Family','DeviceFamily','One-to-one: logical grouping for service planning'),
('TRIMEDX_MMD','PM_SCHEDULE','PM Template','MaintenanceSchedule','One-to-one: each PM template row'),
('TRIMEDX_MMD','SERVICE_COST_ESTIMATE','Cost Estimate','ServiceCost','One-to-one: annual cost per device'),
('SITE_INVENTORY','EQUIPMENT_LIST','Equipment','SiteEquipment','One-to-one: each physical device instance at the site'),
('SITE_INVENTORY','EQUIPMENT_LIST','MANUFACTURER','Manufacturer','Many-to-one: free-text manufacturer resolves via FN_NORMALIZE_MFR'),
('SITE_INVENTORY','SITE_INFO','Site','Site','One-to-one: the hospital being onboarded'),
('SITE_INVENTORY','DEPARTMENT','Department','Department','One-to-one: department within the site');



-- =============================================================================
-- >>> Layer 3 (abstract) - unified entity and relationship views
-- =============================================================================

CREATE OR REPLACE VIEW VW_ONT_ALL_ENTITIES AS
SELECT NODE_ID, NODE_TYPE, NAME, PROPS
FROM KG_NODE
WHERE NODE_TYPE != 'OntologyClass';

CREATE OR REPLACE VIEW REL_RESOLVED AS
SELECT
    e.EDGE_ID,
    e.EDGE_TYPE,
    e.SRC_ID,
    src.NODE_TYPE AS SRC_TYPE,
    src.NAME      AS SRC_NAME,
    e.DST_ID,
    dst.NODE_TYPE AS DST_TYPE,
    dst.NAME      AS DST_NAME,
    e.WEIGHT,
    e.PROPS       AS EDGE_PROPS
FROM KG_EDGE e
JOIN KG_NODE src ON src.NODE_ID = e.SRC_ID
JOIN KG_NODE dst ON dst.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE != 'subClassOf';



-- =============================================================================
-- >>> Layer 3 (hierarchy) - subClassOf views for class traversal
-- =============================================================================

CREATE OR REPLACE VIEW VW_ONT_SUBCLASS_OF AS
SELECT e.SRC_ID, src.NAME AS CHILD_CLASS, e.DST_ID, dst.NAME AS PARENT_CLASS
FROM KG_EDGE e
JOIN KG_NODE src ON src.NODE_ID = e.SRC_ID
JOIN KG_NODE dst ON dst.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'subClassOf';

CREATE OR REPLACE VIEW VW_ANCESTORS AS
SELECT child.NAME AS CLASS_NAME, parent.NAME AS ANCESTOR, e.EDGE_ID
FROM KG_EDGE e
JOIN KG_NODE child  ON child.NODE_ID  = e.SRC_ID
JOIN KG_NODE parent ON parent.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'subClassOf';

CREATE OR REPLACE VIEW VW_DESCENDANTS AS
SELECT parent.NAME AS CLASS_NAME, child.NAME AS DESCENDANT, e.EDGE_ID
FROM KG_EDGE e
JOIN KG_NODE child  ON child.NODE_ID  = e.SRC_ID
JOIN KG_NODE parent ON parent.NODE_ID = e.DST_ID
WHERE e.EDGE_TYPE = 'subClassOf';

CREATE OR REPLACE VIEW VW_ONT_HIERARCHY_STATS AS
SELECT
    oc.CLASS_NAME,
    oc.PARENT_CLASS,
    oc.IS_ABSTRACT,
    oc.DOMAIN_GROUP,
    (SELECT COUNT(*) FROM KG_NODE n WHERE n.NODE_TYPE = oc.CLASS_NAME) AS INSTANCE_COUNT
FROM ONT_CLASS oc;



-- =============================================================================
-- >>> Graph traversal tools - 4 SQL UDFs over the class hierarchy (subClassOf)
-- >>> used as agent tools
-- =============================================================================

-- GET_ANCESTORS: walk subClassOf edges upward from a given class
CREATE OR REPLACE FUNCTION GET_ANCESTORS_TOOL(CONCEPT STRING)
RETURNS TABLE (ANCESTOR STRING, DEPTH NUMBER)
AS $$
  WITH RECURSIVE anc(cls, depth) AS (
    SELECT PARENT_CLASS, 1 FROM ONT_CLASS WHERE CLASS_NAME = CONCEPT AND PARENT_CLASS IS NOT NULL
    UNION ALL
    SELECT oc.PARENT_CLASS, a.depth+1 FROM anc a JOIN ONT_CLASS oc ON oc.CLASS_NAME = a.cls WHERE oc.PARENT_CLASS IS NOT NULL
  )
  SELECT cls, depth FROM anc ORDER BY depth
$$;

-- EXPAND_DESCENDANTS: walk subClassOf edges downward from a root class
CREATE OR REPLACE FUNCTION EXPAND_DESCENDANTS_TOOL(ROOT_CONCEPT STRING)
RETURNS TABLE (DESCENDANT STRING, DEPTH NUMBER, PATH STRING)
AS $$
  WITH RECURSIVE desc_tree(cls, depth, path) AS (
    SELECT CLASS_NAME, 1, ROOT_CONCEPT||' > '||CLASS_NAME
    FROM ONT_CLASS WHERE PARENT_CLASS = ROOT_CONCEPT
    UNION ALL
    SELECT oc.CLASS_NAME, d.depth+1, d.path||' > '||oc.CLASS_NAME
    FROM desc_tree d JOIN ONT_CLASS oc ON oc.PARENT_CLASS = d.cls
  )
  SELECT cls, depth, path FROM desc_tree ORDER BY depth, cls
$$;

-- GET_DIRECT_CHILDREN: immediate subclasses only
CREATE OR REPLACE FUNCTION GET_DIRECT_CHILDREN_TOOL(PARENT_CONCEPT STRING)
RETURNS TABLE (CHILD STRING)
AS $$
  SELECT CLASS_NAME FROM ONT_CLASS WHERE PARENT_CLASS = PARENT_CONCEPT ORDER BY CLASS_NAME
$$;

-- GET_HIERARCHY_PATH: path between two classes via subClassOf
CREATE OR REPLACE FUNCTION GET_HIERARCHY_PATH_TOOL(START_CONCEPT STRING, END_CONCEPT STRING)
RETURNS TABLE (PATH STRING, DEPTH NUMBER)
AS $$
  WITH RECURSIVE walk(cls, depth, path) AS (
    SELECT START_CONCEPT, 0, START_CONCEPT
    UNION ALL
    SELECT oc.PARENT_CLASS, w.depth+1, w.path||' > '||oc.PARENT_CLASS
    FROM walk w JOIN ONT_CLASS oc ON oc.CLASS_NAME = w.cls
    WHERE oc.PARENT_CLASS IS NOT NULL AND w.depth < 10
  )
  SELECT path, depth FROM walk WHERE cls = END_CONCEPT
$$;



-- =============================================================================
-- >>> Provenance & identity rules - already seeded in ONT_OBJECT_SOURCE and
-- >>> ONT_IDENTITY_RULE above. This section adds the key summary view.
-- =============================================================================

-- Summary view: matching statistics for the site onboarding
CREATE OR REPLACE VIEW VW_MATCH_SUMMARY AS
SELECT
    COUNT(*)                                                    AS TOTAL_EQUIPMENT,
    SUM(IFF(IS_MATCHED, 1, 0))                                AS MATCHED_COUNT,
    SUM(IFF(NOT IS_MATCHED, 1, 0))                             AS UNMATCHED_COUNT,
    ROUND(100.0 * SUM(IFF(IS_MATCHED, 1, 0)) / COUNT(*), 1)  AS MATCH_RATE_PCT,
    SUM(IFF(MATCH_BASIS = 'EXACT_MODEL', 1, 0))               AS EXACT_MATCHES,
    SUM(IFF(MATCH_BASIS = 'FUZZY_MODEL', 1, 0))               AS FUZZY_MODEL_MATCHES,
    SUM(IFF(MATCH_BASIS = 'DESC_MATCH', 1, 0))                AS DESC_MATCHES
FROM STG_SITE_EQUIPMENT
WHERE STATUS != 'DECOMMISSIONED';

-- Summary view: estimated annual cost for the site's matched fleet
CREATE OR REPLACE VIEW VW_SITE_COST_ESTIMATE AS
SELECT
    se.EQUIP_ID,
    se.RAW_MFR,
    se.RAW_MODEL,
    se.RAW_DESC,
    d.DEPT_NAME,
    dev.DEVICE_NAME                AS MATCHED_DEVICE,
    dev.CANONICAL_MFR              AS MATCHED_MFR,
    dev.FAMILY_NAME,
    sc.ANNUAL_PARTS_COST,
    sc.ANNUAL_LABOR_COST,
    sc.ANNUAL_TOTAL_COST,
    sc.RISK_TIER,
    sc.COST_CONFIDENCE,
    se.MATCH_BASIS,
    se.IS_MATCHED
FROM STG_SITE_EQUIPMENT se
LEFT JOIN STG_DEVICE dev ON dev.CATALOG_ID = se.RESOLVED_CATALOG_ID
LEFT JOIN TRIMEDX_MMD.MASTER.SERVICE_COST_ESTIMATE sc ON sc.CATALOG_ID = se.RESOLVED_CATALOG_ID
LEFT JOIN SITE_INVENTORY.RAW.DEPARTMENT d ON d.DEPT_ID = se.DEPT_ID
WHERE se.STATUS != 'DECOMMISSIONED';
