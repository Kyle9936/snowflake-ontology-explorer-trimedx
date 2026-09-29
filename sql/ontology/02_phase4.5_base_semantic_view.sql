-- =============================================================================
-- PHASE 4.5 - Base Semantic View (raw source tables, no ontology resolution)
-- MMD_ONTOLOGY  .  FDA_DEVICES.ONTOLOGY
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_BASE

  TABLES (
    fda_devices AS FDA_DEVICES.GUDID.DEVICE_RECORD
      PRIMARY KEY (GUDID_DI)
      COMMENT = 'FDA GUDID device registry. COMPANY_NAME is free-text and inconsistent across records for the same manufacturer.',
    trimedx_catalog AS TRIMEDX_MMD.MASTER.DEVICE_CATALOG
      PRIMARY KEY (CATALOG_ID)
      COMMENT = 'TriMedx master device catalog (Make, Model, Description).',
    trimedx_mfr AS TRIMEDX_MMD.MASTER.MANUFACTURER
      PRIMARY KEY (MFR_ID)
      COMMENT = 'TriMedx manufacturer master. MFR_NAME uses internal abbreviations.',
    trimedx_family AS TRIMEDX_MMD.MASTER.DEVICE_FAMILY
      PRIMARY KEY (FAMILY_ID)
      COMMENT = 'Device family groupings for service planning and pricing.',
    trimedx_pm AS TRIMEDX_MMD.MASTER.PM_SCHEDULE
      PRIMARY KEY (PM_ID)
      COMMENT = 'Preventive maintenance schedule templates by device family.',
    trimedx_cost AS TRIMEDX_MMD.MASTER.SERVICE_COST_ESTIMATE
      PRIMARY KEY (COST_ID)
      COMMENT = 'Annual service cost estimates per device model.',
    site_equipment AS SITE_INVENTORY.RAW.EQUIPMENT_LIST
      PRIMARY KEY (EQUIP_ID)
      COMMENT = 'Raw equipment inventory from the site being onboarded.',
    site_info AS SITE_INVENTORY.RAW.SITE_INFO
      PRIMARY KEY (SITE_ID)
      COMMENT = 'Hospital site being onboarded for device management.',
    site_dept AS SITE_INVENTORY.RAW.DEPARTMENT
      PRIMARY KEY (DEPT_ID)
      COMMENT = 'Departments within the site.'
  )

  RELATIONSHIPS (
    catalog_to_mfr AS trimedx_catalog (MFR_ID) REFERENCES trimedx_mfr,
    catalog_to_family AS trimedx_catalog (FAMILY_ID) REFERENCES trimedx_family,
    cost_to_catalog AS trimedx_cost (CATALOG_ID) REFERENCES trimedx_catalog,
    pm_to_family AS trimedx_pm (FAMILY_ID) REFERENCES trimedx_family,
    equip_to_dept AS site_equipment (DEPT_ID) REFERENCES site_dept,
    equip_to_site AS site_equipment (SITE_ID) REFERENCES site_info,
    dept_to_site AS site_dept (SITE_ID) REFERENCES site_info
  )

  FACTS (
    trimedx_pm.est_labor_hours AS est_labor_hours COMMENT = 'Estimated technician hours per PM event',
    trimedx_cost.annual_parts_cost AS annual_parts_cost COMMENT = 'Estimated annual parts spend',
    trimedx_cost.annual_labor_cost AS annual_labor_cost COMMENT = 'Estimated annual labor cost',
    trimedx_cost.annual_pm_cost AS annual_pm_cost COMMENT = 'Preventive-maintenance portion of annual labor cost. Already included in labor; never add it to parts + labor.',
    trimedx_cost.annual_total_cost AS annual_total_cost
      WITH SYNONYMS = ('total cost', 'annual cost', 'service cost', 'maintenance cost')
      COMMENT = 'Total annual service cost per device model'
  )

  DIMENSIONS (
    fda_devices.gudid_di AS gudid_di COMMENT = 'FDA Global Unique Device Identifier',
    fda_devices.company_name AS company_name WITH SYNONYMS = ('fda manufacturer', 'fda maker') COMMENT = 'FDA free-text manufacturer name',
    fda_devices.brand_name AS brand_name COMMENT = 'FDA commercial brand name',
    fda_devices.version_model_number AS version_model_number COMMENT = 'FDA model/version number',
    fda_devices.device_description AS device_description COMMENT = 'Verbose FDA device description',
    fda_devices.device_class AS device_class WITH SYNONYMS = ('risk class', 'fda class') COMMENT = 'FDA risk classification: 1, 2, or 3',
    fda_devices.product_code AS product_code COMMENT = '3-letter FDA product code',
    fda_devices.device_status AS device_status COMMENT = 'In Commercial Distribution or Not in Commercial Distribution',

    trimedx_catalog.catalog_id AS catalog_id COMMENT = 'TriMedx internal catalog identifier',
    trimedx_catalog.model_number AS model_number WITH SYNONYMS = ('model', 'model number') COMMENT = 'TriMedx internal model designation',
    trimedx_catalog.device_name AS device_name WITH SYNONYMS = ('device', 'device name', 'equipment name') COMMENT = 'Short commercial device name',
    trimedx_catalog.device_desc AS device_desc COMMENT = 'Abbreviated device description',
    trimedx_catalog.status AS status WITH SYNONYMS = ('catalog status') COMMENT = 'ACTIVE, DISCONTINUED, or LEGACY',

    trimedx_mfr.mfr_id AS mfr_id COMMENT = 'TriMedx manufacturer ID',
    trimedx_mfr.mfr_name AS mfr_name WITH SYNONYMS = ('manufacturer', 'make', 'maker', 'vendor', 'oem') COMMENT = 'TriMedx abbreviated manufacturer name',
    trimedx_mfr.mfr_full_name AS mfr_full_name COMMENT = 'Longer manufacturer name',

    trimedx_family.family_id AS family_id COMMENT = 'Device family ID',
    trimedx_family.family_name AS family_name WITH SYNONYMS = ('device family', 'device type', 'device category', 'equipment type') COMMENT = 'Logical device grouping',
    trimedx_family.family_category AS family_category WITH SYNONYMS = ('category') COMMENT = 'Broad category',

    trimedx_pm.pm_type AS pm_type WITH SYNONYMS = ('maintenance type') COMMENT = 'FULL_PM, INTERIM_PM, CALIBRATION, or SAFETY_CHECK',
    trimedx_pm.interval_months AS interval_months WITH SYNONYMS = ('pm frequency', 'maintenance interval') COMMENT = 'Months between PMs',

    site_equipment.equip_id AS equip_id COMMENT = 'Site equipment identifier',
    site_equipment.manufacturer AS manufacturer WITH SYNONYMS = ('site manufacturer') COMMENT = 'Free-text manufacturer from site inventory',
    site_equipment.model AS model WITH SYNONYMS = ('site model') COMMENT = 'Free-text model from site inventory',
    site_equipment.device_description AS device_description WITH SYNONYMS = ('site description') COMMENT = 'Free-text device description from site',
    site_equipment.serial_number AS serial_number COMMENT = 'Device serial number',
    site_equipment.condition AS condition WITH SYNONYMS = ('device condition') COMMENT = 'GOOD, FAIR, POOR, or UNKNOWN',
    site_equipment.status AS status WITH SYNONYMS = ('service status') COMMENT = 'IN_SERVICE, OUT_OF_SERVICE, SPARE, or DECOMMISSIONED',
    site_equipment.install_date AS install_date COMMENT = 'Date device was installed at site',
    site_equipment.last_pm_date AS last_pm_date COMMENT = 'Date of last preventive maintenance',

    site_info.site_name AS site_name WITH SYNONYMS = ('hospital', 'facility') COMMENT = 'Hospital/facility name',
    site_info.site_type AS site_type COMMENT = 'HOSPITAL, SURGERY_CENTER, or CLINIC',
    site_info.bed_count AS bed_count COMMENT = 'Number of beds at the facility',

    site_dept.dept_name AS dept_name WITH SYNONYMS = ('department', 'unit', 'area') COMMENT = 'Department name at the site'
  )

  METRICS (
    total_annual_cost AS SUM(trimedx_cost.annual_total_cost)
      WITH SYNONYMS = ('fleet cost', 'total service cost', 'total maintenance cost')
      COMMENT = 'Sum of annual service costs across matched devices',
    total_annual_parts AS SUM(trimedx_cost.annual_parts_cost) COMMENT = 'Sum of annual parts costs',
    total_annual_labor AS SUM(trimedx_cost.annual_labor_cost) COMMENT = 'Sum of annual labor costs',
    device_count AS COUNT(DISTINCT trimedx_catalog.catalog_id)
      WITH SYNONYMS = ('number of devices', 'fleet size', 'how many devices')
      COMMENT = 'Count of distinct device models',
    equipment_count AS COUNT(DISTINCT site_equipment.equip_id)
      WITH SYNONYMS = ('number of equipment', 'inventory size', 'how many pieces of equipment')
      COMMENT = 'Count of physical equipment items at the site'
  )

  COMMENT = 'Base semantic view over raw MMD source tables - no ontology resolution, for baseline comparison';
