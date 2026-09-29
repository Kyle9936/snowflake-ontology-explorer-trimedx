-- =============================================================================
-- PHASE 5 - Ontology Layer Semantic Views (KG, Ontology, Metadata)
-- MMD_ONTOLOGY  .  FDA_DEVICES.ONTOLOGY
-- =============================================================================

-- --------------------------------------------------------------------------
-- 1. KG Model  (resolved entities and relationships)
-- --------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_KG_MODEL

  TABLES (
    device AS FDA_DEVICES.ONTOLOGY.V_DEVICE
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Canonical device resolved across FDA, Trimedx, and site inventory.',
    manufacturer AS FDA_DEVICES.ONTOLOGY.V_MANUFACTURER
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Canonical manufacturer. Resolves all name variants.',
    device_family AS FDA_DEVICES.ONTOLOGY.V_DEVICE_FAMILY
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Logical device grouping for pricing and PM.',
    site_equipment AS FDA_DEVICES.ONTOLOGY.V_SITE_EQUIPMENT
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Site inventory record with match status.',
    service_cost AS FDA_DEVICES.ONTOLOGY.V_SERVICE_COST
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Annual service cost estimate per device.',
    maintenance AS FDA_DEVICES.ONTOLOGY.V_MAINTENANCE_SCHEDULE
      PRIMARY KEY (NODE_ID)
      COMMENT = 'PM schedule template by device family.',
    fda_record AS FDA_DEVICES.ONTOLOGY.V_FDA_RECORD
      PRIMARY KEY (NODE_ID)
      COMMENT = 'FDA GUDID registry entry.',
    site AS FDA_DEVICES.ONTOLOGY.V_SITE
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Hospital site being onboarded.',
    department AS FDA_DEVICES.ONTOLOGY.V_DEPARTMENT
      PRIMARY KEY (NODE_ID)
      COMMENT = 'Department within the site.',
    site_fleet AS FDA_DEVICES.ONTOLOGY.VW_SITE_COST_ESTIMATE
      PRIMARY KEY (EQUIP_ID)
      COMMENT = 'One row per physical device at the site being onboarded (decommissioned excluded), with its resolved canonical device, annual cost, and match status. Use for fleet cost, match rate, department, and unmatched-device questions.'
  )

  RELATIONSHIPS (
    device_to_mfr AS device (MFR_ID) REFERENCES manufacturer (MFR_ID),
    device_to_family AS device (FAMILY_ID) REFERENCES device_family (FAMILY_ID),
    cost_to_device AS service_cost (CATALOG_ID) REFERENCES device (CATALOG_ID),
    equip_to_device AS site_equipment (RESOLVED_CATALOG_ID) REFERENCES device (CATALOG_ID),
    equip_to_dept AS site_equipment (DEPT_ID) REFERENCES department (DEPT_ID),
    maintenance_to_family AS maintenance (FAMILY_ID) REFERENCES device_family (FAMILY_ID),
    dept_to_site AS department (SITE_ID) REFERENCES site (SITE_ID)
  )

  FACTS (
    service_cost.annual_parts_cost AS annual_parts_cost COMMENT = 'Annual parts cost per device',
    service_cost.annual_labor_cost AS annual_labor_cost COMMENT = 'Annual labor cost per device',
    service_cost.annual_pm_cost AS annual_pm_cost COMMENT = 'Preventive-maintenance portion of annual LABOR cost. Already included in annual_labor_cost; never add it to parts + labor.',
    service_cost.annual_total_cost AS annual_total_cost COMMENT = 'Total annual service cost per device = annual_parts_cost + annual_labor_cost (PM is inside labor).',
    maintenance.interval_months AS interval_months COMMENT = 'Months between PMs',
    maintenance.est_labor_hours AS est_labor_hours COMMENT = 'Estimated tech hours per PM',
    manufacturer.device_count AS device_count COMMENT = 'Number of device models from this manufacturer',
    site_fleet.fleet_annual_cost AS annual_total_cost COMMENT = 'Annual service cost for this physical device (NULL when unmatched)',
    site_fleet.fleet_parts_cost AS annual_parts_cost COMMENT = 'Annual parts cost for this physical device',
    site_fleet.fleet_labor_cost AS annual_labor_cost COMMENT = 'Annual labor cost for this physical device',
    site_fleet.fleet_search_score AS search_score COMMENT = 'Cortex Search cosine similarity of the top catalog candidate (0-1)'
  )

  DIMENSIONS (
    device.device_name AS device_name WITH SYNONYMS = ('device', 'equipment', 'model name') COMMENT = 'Canonical device name',
    device.tmx_model AS tmx_model WITH SYNONYMS = ('model', 'model number') COMMENT = 'Trimedx model designation',
    device.canonical_mfr AS canonical_mfr WITH SYNONYMS = ('manufacturer', 'make', 'maker', 'oem') COMMENT = 'Resolved manufacturer name',
    device.family_name AS family_name WITH SYNONYMS = ('device type', 'family', 'category') COMMENT = 'Device family name',
    device.family_category AS family_category COMMENT = 'Broad category',
    device.catalog_status AS catalog_status COMMENT = 'ACTIVE, DISCONTINUED, or LEGACY',
    device.fda_class AS fda_class WITH SYNONYMS = ('risk class') COMMENT = 'FDA risk classification',
    device.source_systems AS source_systems COMMENT = 'Which source systems this device appears in',

    manufacturer.manufacturer_name AS manufacturer_name COMMENT = 'Canonical manufacturer name',
    manufacturer.mfr_country AS mfr_country COMMENT = 'Manufacturer country of origin',
    manufacturer.fda_name_variants AS fda_name_variants COMMENT = 'All FDA name variants for this manufacturer',

    site_equipment.equipment_name AS equipment_name COMMENT = 'Raw equipment name from site inventory',
    site_equipment.raw_mfr AS raw_mfr COMMENT = 'Original manufacturer text from site',
    site_equipment.raw_model AS raw_model COMMENT = 'Original model text from site',
    site_equipment.raw_desc AS raw_desc COMMENT = 'Original description from site',
    site_equipment.match_basis AS match_basis WITH SYNONYMS = ('match type', 'how matched') COMMENT = 'EXACT_MODEL or FUZZY_MODEL (rules), SEARCH_MATCH (confident Cortex Search), or NEEDS_REVIEW',
    site_equipment.is_matched AS is_matched WITH SYNONYMS = ('matched', 'resolved') COMMENT = 'Whether equipment was matched to a canonical device',
    site_equipment.condition AS condition COMMENT = 'GOOD, FAIR, POOR, or UNKNOWN',

    service_cost.risk_tier AS risk_tier WITH SYNONYMS = ('risk level') COMMENT = 'HIGH, MEDIUM, or LOW',
    service_cost.cost_confidence AS cost_confidence COMMENT = 'Confidence in the cost estimate',

    site.site_name AS site_name WITH SYNONYMS = ('hospital', 'facility') COMMENT = 'Hospital name',
    department.dept_name AS dept_name WITH SYNONYMS = ('department', 'unit') COMMENT = 'Department name',

    site_fleet.fleet_equip_id AS equip_id COMMENT = 'Site equipment identifier',
    site_fleet.fleet_raw_mfr AS raw_mfr COMMENT = 'Manufacturer as written in the site inventory',
    site_fleet.fleet_raw_model AS raw_model COMMENT = 'Model as written in the site inventory',
    site_fleet.fleet_raw_desc AS raw_desc COMMENT = 'Description as written in the site inventory',
    site_fleet.fleet_dept_name AS dept_name COMMENT = 'Department where the device is installed',
    site_fleet.fleet_matched_device AS matched_device COMMENT = 'Canonical device the site record resolved to',
    site_fleet.fleet_matched_mfr AS matched_mfr COMMENT = 'Canonical manufacturer the site record resolved to',
    site_fleet.fleet_family_name AS family_name COMMENT = 'Device family of the resolved device',
    site_fleet.fleet_risk_tier AS risk_tier COMMENT = 'HIGH, MEDIUM, or LOW',
    site_fleet.fleet_match_basis AS match_basis COMMENT = 'EXACT_MODEL or FUZZY_MODEL (deterministic rules), SEARCH_MATCH (confident Cortex Search match), or NEEDS_REVIEW (sent to a human)',
    site_fleet.fleet_suggested_device AS suggested_device COMMENT = 'Top Cortex Search candidate from the Trimedx catalog. For NEEDS_REVIEW rows this pre-fills the reviewer',
    site_fleet.fleet_search_agrees AS search_agrees WITH SYNONYMS = ('independently confirmed', 'double checked') COMMENT = 'TRUE when Cortex Search independently picked the same device the rules matched',
    site_fleet.fleet_is_matched AS is_matched COMMENT = 'TRUE when the device resolved to a canonical device and has a cost estimate'
  )

  METRICS (
    site_fleet.site_annual_cost AS SUM(site_fleet.fleet_annual_cost)
      WITH SYNONYMS = ('fleet cost', 'annual fleet cost', 'total annual cost', 'site cost estimate', 'maintenance cost', 'quote')
      COMMENT = 'Estimated annual service cost for the site fleet: sum over every matched physical device',
    site_fleet.site_device_count AS COUNT(site_fleet.fleet_equip_id)
      WITH SYNONYMS = ('fleet size', 'number of devices at the site')
      COMMENT = 'Number of active physical devices at the site',
    catalog_model_cost AS SUM(service_cost.annual_total_cost)
      COMMENT = 'Sum of per-model catalog costs (one row per catalog model, not per physical device). Not a fleet cost.',
    total_parts_cost AS SUM(service_cost.annual_parts_cost) COMMENT = 'Total annual parts spend',
    total_labor_cost AS SUM(service_cost.annual_labor_cost) COMMENT = 'Total annual labor cost',
    matched_equipment_count AS COUNT_IF(site_equipment.is_matched = TRUE)
      WITH SYNONYMS = ('matched devices', 'resolved devices')
      COMMENT = 'Number of site equipment items successfully matched',
    unmatched_equipment_count AS COUNT_IF(site_equipment.is_matched = FALSE)
      WITH SYNONYMS = ('unmatched devices', 'unresolved devices')
      COMMENT = 'Number of site equipment items that could not be matched',
    match_rate AS ROUND(100.0 * COUNT_IF(site_equipment.is_matched = TRUE) / NULLIF(COUNT(site_equipment.is_matched), 0), 1)
      WITH SYNONYMS = ('match percentage', 'resolution rate')
      COMMENT = 'Percentage of site equipment matched to canonical devices'
  )

  COMMENT = 'Resolved MMD knowledge graph with canonical devices, manufacturers, families, costs, and match status'

  AI_VERIFIED_QUERIES (
    vq_fleet_cost AS (
      QUESTION 'What is the estimated annual maintenance cost for this site''s device fleet?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT SUM(fleet_annual_cost) AS estimated_annual_cost, COUNT_IF(fleet_is_matched) AS priced_devices, COUNT(*) AS total_devices, COUNT(*) - COUNT_IF(fleet_is_matched) AS unpriced_devices FROM __site_fleet'
    ),
    vq_match_rate AS (
      QUESTION 'What is the current match rate for the site inventory?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT COUNT(*) AS total_devices, COUNT_IF(fleet_is_matched) AS matched_devices, ROUND(100.0 * COUNT_IF(fleet_is_matched) / COUNT(*), 1) AS match_rate_pct FROM __site_fleet'
    ),
    vq_match_basis AS (
      QUESTION 'How were the site devices matched, by match method?'
      SQL 'SELECT fleet_match_basis, COUNT(*) AS devices FROM __site_fleet GROUP BY fleet_match_basis ORDER BY devices DESC'
    ),
    vq_cost_by_department AS (
      QUESTION 'What is the estimated annual cost by department?'
      SQL 'SELECT fleet_dept_name, COUNT(*) AS devices, COUNT_IF(fleet_is_matched) AS priced_devices, SUM(fleet_annual_cost) AS annual_cost FROM __site_fleet GROUP BY fleet_dept_name ORDER BY annual_cost DESC NULLS LAST'
    ),
    vq_unmatched_devices AS (
      QUESTION 'Which devices could not be matched?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT fleet_equip_id, fleet_raw_mfr, fleet_raw_model, fleet_raw_desc, fleet_dept_name, fleet_suggested_device, fleet_search_score FROM __site_fleet WHERE NOT fleet_is_matched ORDER BY fleet_raw_mfr, fleet_raw_model'
    ),
    vq_independent_confirmation AS (
      QUESTION 'How many matches were independently confirmed by Cortex Search?'
      SQL 'SELECT COUNT_IF(fleet_is_matched) AS matched_devices, COUNT_IF(fleet_is_matched AND fleet_search_agrees) AS confirmed_by_search, COUNT_IF(NOT fleet_is_matched) AS needs_review FROM __site_fleet'
    )
  );


-- --------------------------------------------------------------------------
-- 2. Ontology Model  (cross-type entity and relationship counts)
-- --------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_ONTOLOGY_MODEL

  TABLES (
    all_entities AS FDA_DEVICES.ONTOLOGY.VW_ONT_ALL_ENTITIES
      COMMENT = 'All non-class KG nodes.',
    relationships AS FDA_DEVICES.ONTOLOGY.REL_RESOLVED
      COMMENT = 'All resolved relationships between entities.',
    hierarchy AS FDA_DEVICES.ONTOLOGY.VW_ONT_HIERARCHY_STATS
      COMMENT = 'Ontology class hierarchy with instance counts.'
  )

  FACTS (
    hierarchy.instance_count AS instance_count COMMENT = 'Number of instances of this class in the KG'
  )

  DIMENSIONS (
    all_entities.node_type AS node_type WITH SYNONYMS = ('type', 'class', 'kind') COMMENT = 'Ontology class of the entity',
    all_entities.name AS name COMMENT = 'Display name of the entity',
    relationships.edge_type AS edge_type WITH SYNONYMS = ('relation', 'edge type') COMMENT = 'Type of relationship',
    relationships.src_type AS src_type COMMENT = 'Source entity class',
    relationships.dst_type AS dst_type COMMENT = 'Target entity class',
    hierarchy.class_name AS class_name COMMENT = 'Ontology class name',
    hierarchy.parent_class AS parent_class COMMENT = 'Parent class in hierarchy',
    hierarchy.domain_group AS domain_group COMMENT = 'Domain grouping'
  )

  COMMENT = 'Abstract ontology view: entity counts by type, relationship distribution, instance overview';


-- --------------------------------------------------------------------------
-- 3. Metadata Model  (ontology self-description)
-- --------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_METADATA_MODEL

  TABLES (
    classes AS FDA_DEVICES.ONTOLOGY.ONT_CLASS
      PRIMARY KEY (CLASS_NAME)
      COMMENT = 'Ontology class definitions.',
    relations AS FDA_DEVICES.ONTOLOGY.ONT_RELATION_DEF
      PRIMARY KEY (RELATION_NAME)
      COMMENT = 'Relationship definitions.',
    sources AS FDA_DEVICES.ONTOLOGY.ONT_OBJECT_SOURCE
      COMMENT = 'Source table mappings per class.',
    identity_rules AS FDA_DEVICES.ONTOLOGY.ONT_IDENTITY_RULE
      COMMENT = 'Identity resolution rules.',
    class_maps AS FDA_DEVICES.ONTOLOGY.ONT_CLASS_MAP
      COMMENT = 'Source label to ontology class mappings.'
  )

  FACTS (
    identity_rules.rule_order AS rule_order COMMENT = 'Priority order for identity resolution (1 = highest)'
  )

  DIMENSIONS (
    classes.class_name AS class_name WITH SYNONYMS = ('class', 'entity type') COMMENT = 'Ontology class name',
    classes.parent_class AS parent_class COMMENT = 'Parent class in hierarchy',
    classes.is_abstract AS is_abstract COMMENT = 'Whether this is an abstract class',
    classes.description AS description COMMENT = 'Business description of the class',
    classes.domain_group AS domain_group COMMENT = 'Domain group',
    relations.relation_name AS relation_name WITH SYNONYMS = ('relationship', 'edge') COMMENT = 'Relationship name',
    relations.source_class AS source_class COMMENT = 'Source class',
    relations.target_class AS target_class COMMENT = 'Target class',
    relations.cardinality AS cardinality COMMENT = '1:1, 1:N, N:1, or N:M',
    sources.source_system AS source_system WITH SYNONYMS = ('system', 'database') COMMENT = 'Source database',
    sources.source_table AS source_table COMMENT = 'Source table name',
    sources.source_columns AS source_columns COMMENT = 'Key columns from the source',
    identity_rules.key_system AS key_system COMMENT = 'Identity key system name',
    identity_rules.key_description AS key_description COMMENT = 'Description of the identity key',
    identity_rules.confidence AS confidence WITH SYNONYMS = ('match confidence') COMMENT = 'HIGH, MEDIUM, or LOW',
    class_maps.source_label AS source_label COMMENT = 'What the source system calls this entity'
  )

  COMMENT = 'Ontology metadata: class definitions, source mappings, identity rules';
