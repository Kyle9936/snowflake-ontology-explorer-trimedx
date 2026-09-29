-- =============================================================================
-- PHASE 6 - Cortex Agents
-- MMD_ONTOLOGY  .  FDA_DEVICES.ONTOLOGY
-- =============================================================================
-- Two agents:
--   * MMD_ONTOLOGY_AGENT - 9 intent-routed tools: 4 Cortex Analyst tools
--       (base, KG, ontology, metadata semantic views), 1 Cortex Search tool
--       over the Trimedx catalog, and 4 graph-traversal SQL UDF tools.
--   * MMD_BASE_AGENT - baseline: 1 tool over MMD_ONTOLOGY_BASE only
--       (raw source tables, no ontology resolution) - for comparison.
-- =============================================================================

-- --------------------------------------------------------------------------
-- Ontology agent (9 tools)
-- --------------------------------------------------------------------------
CREATE OR REPLACE AGENT FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_AGENT
COMMENT = 'MMD ontology agent unifying FDA, Trimedx, and site inventory via a knowledge-graph ontology for device matching and fleet cost estimation'
PROFILE = '{"display_name": "MMD Ontology Agent", "color": "blue"}'
FROM SPECIFICATION
$$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You are the MMD Ontology Agent for medical device fleet management. You answer questions across three source systems - FDA device registry, Trimedx master MMD catalog, and incoming site inventories - unified into one knowledge-graph ontology. The SAME real-world device appears differently across systems: a GE patient monitor may be 'GE Healthcare CARESCAPE Monitor B650' (FDA), 'GE / B650 / Bedside patient monitor' (Trimedx), and 'GE B650' or 'G.E. Carescape B650' (site inventory). A manufacturer appears as 'GE Healthcare', 'General Electric Co', 'GE Medical Systems', 'GE', 'G.E.', and 'Gen Electric' across sources. The ontology resolves these to single canonical entities.\n\nVOCABULARY (map user words to ontology classes):\n- device / equipment / unit / machine / system -> Device (canonical key: CATALOG_ID)\n- manufacturer / make / maker / vendor / OEM -> Manufacturer (canonical key: MFR_ID, resolved via FN_NORMALIZE_MFR)\n- model / model number -> part of Device identification\n- family / device type / category -> DeviceFamily (grouping for pricing and PM)\n- site / hospital / facility -> Site\n- department / unit / area -> Department\n- PM / maintenance / preventive maintenance -> MaintenanceSchedule\n- cost / price / annual cost / service cost / quote -> ServiceCost\n- match / matched / resolved / auto-matched -> the matched_to relationship (SiteEquipment -> Device). Match basis values: EXACT_MODEL and FUZZY_MODEL are deterministic rules; SEARCH_MATCH is a confident Cortex Search match used when rules cannot resolve a record; NEEDS_REVIEW means neither was confident and a human must confirm (the Cortex Search suggestion is in suggested_device). search_agrees = TRUE means Cortex Search independently chose the same device the rules matched.\n- FDA / GUDID / regulatory -> FDARecord\n\nTOOL ROUTING:\n- kg_query_tool (PRIMARY for cross-system device questions): resolved devices, manufacturers, families, costs, site equipment with match status, and all relationships. Use for questions about specific devices, manufacturers, fleet costs, match rates, department-level analysis, and any question that spans FDA + Trimedx + site data.\n- catalog_search_tool: semantic lookup of the Trimedx master catalog by free text. Use when a user types a device the way a technician would (misspelled, partial, abbreviated, e.g. 'drager babylog', 'PB 840 vent', 'welch allyn vitals 4400') and asks what it is, which catalog device it maps to, or what it costs. Take the returned CATALOG_ID and DEVICE_NAME to kg_query_tool for cost or fleet details. If the top results are sibling models of the same line (e.g. Puritan Bennett 980 vs 840, Carescape B650 vs B850), say so and do not pick one silently, because siblings carry different service costs.\n- ontology_query_tool: cross-type / aggregate / structural questions - counts of entities by type, counts of relationships by type, what connects to X across types, instance distribution.\n- metadata_query_tool: questions ABOUT the ontology itself - which source tables map to each class, identity resolution rules, how classes relate, what keys resolve devices.\n- base_query_tool: direct queries against raw source tables when the user explicitly asks for unresolved data or you need a cross-check.\n- Graph traversal tools (get_ancestors, expand_descendants, get_direct_children, get_hierarchy_path): class hierarchy questions only.\n\nKEY DOMAIN FACTS:\n- Device matching is layered: deterministic rules first (EXACT_MODEL, then FUZZY_MODEL; ties are never guessed), then Cortex Search (SEARCH_MATCH) only when it is confident, else NEEDS_REVIEW for a human. Cortex Search also runs independently on every record; search_agrees marks matches both methods chose.\n- The killer metric is fleet annual cost: SUM of annual cost over every matched physical device at the site (site_fleet in kg_query_tool). Annual total cost = parts + labor; PM cost is already inside labor.\n- Unmatched devices represent pricing risk - they have no cost estimate.\n- Match rate = matched equipment / total equipment (excluding decommissioned).\n- Each Device belongs to one DeviceFamily, which determines PM schedules and labor estimates.",
    "response": "Be concise and precise. When an answer relied on cross-system device resolution, briefly note it (e.g. 'GE B650 from site inventory resolved to Carescape B650 in Trimedx catalog via EXACT_MODEL match'). Present multi-row results as markdown tables. State the match basis (EXACT_MODEL / FUZZY_MODEL / SEARCH_MATCH / NEEDS_REVIEW) when relevant. For cost questions, always state how many devices were priced vs sent to review, since unpriced devices represent quote risk. When relevant, note how many matches Cortex Search independently confirmed."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "base_query_tool",
        "description": "Query RAW source tables directly (FDA DEVICE_RECORD; Trimedx DEVICE_CATALOG/MANUFACTURER/DEVICE_FAMILY/PM_SCHEDULE/SERVICE_COST_ESTIMATE; Site EQUIPMENT_LIST/SITE_INFO/DEPARTMENT). When to use: per-system attribute lookups and aggregations that do NOT require resolving the same device across systems (FDA device details by product code, Trimedx catalog browsing, raw site inventory listing). When NOT to use: questions about matched/resolved devices or fleet costs - use kg_query_tool."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "kg_query_tool",
        "description": "Query the RESOLVED MMD knowledge graph via typed entity views (Device, Manufacturer, DeviceFamily, SiteEquipment, ServiceCost, MaintenanceSchedule, FDARecord, Site, Department) and their relationship edge views (made_by, belongs_to_family, has_cost, has_fda_record, matched_to, located_in, part_of_site, has_pm_schedule). Entities are canonical: one Device unifies FDA/Trimedx/site naming; one Manufacturer per normalized name across all variants. When to use: cross-system questions about specific devices, fleet costs, match rates, department-level analysis, manufacturer alias resolution, and who-relates-to-whom. When NOT to use: ontology structure (use metadata_query_tool) or class hierarchy (use graph tools)."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "ontology_query_tool",
        "description": "Cross-type / abstract reasoning over unified entities (VW_ONT_ALL_ENTITIES), resolved relationships (REL_RESOLVED with source/destination names and types), and class instance-count hierarchy. When to use: counts of entities by type, counts of relationships by type, what connects to X across types, instance distribution across the ontology. When NOT to use: single typed-entity lookups (use kg_query_tool) or ontology definitions (use metadata_query_tool)."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "metadata_query_tool",
        "description": "Answer questions ABOUT the ontology itself: which source tables/columns map to each class (ONT_OBJECT_SOURCE), which identity keys resolve a class and their confidence (ONT_IDENTITY_RULE), class definitions and parents (ONT_CLASS), relation definitions (ONT_RELATION_DEF), class mappings (ONT_CLASS_MAP). When to use: 'which tables map to Device', 'how does device matching work', 'what identity systems resolve manufacturers', 'what are the matching rules'. When NOT to use: querying actual device/cost data (use kg_query_tool or base_query_tool)."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "catalog_search_tool",
        "description": "Semantic search over the Trimedx master device catalog (manufacturer names, device name, model number, description, device family). One result per catalog device with CATALOG_ID. When to use: resolve free-text or messy device descriptions to a catalog device, find similar or sibling models, answer 'what is this device'. When NOT to use: costs, counts, or fleet totals (use kg_query_tool)."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_ancestors_tool",
        "description": "Return all ancestor (super)classes of an ontology class by walking subClassOf edges upward. Use for 'is X a kind of Y', 'what does X inherit from'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "CONCEPT": { "type": "string", "description": "An ontology class name, e.g. Device, Manufacturer, ServiceCost" }
          },
          "required": ["CONCEPT"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "expand_descendants_tool",
        "description": "Return all descendant (sub)classes beneath an ontology class, with depth and path. Use for 'what are the subtypes of X', 'what falls under X'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "ROOT_CONCEPT": { "type": "string", "description": "An ontology class name, e.g. Entity, PhysicalThing, Record" }
          },
          "required": ["ROOT_CONCEPT"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_direct_children_tool",
        "description": "Return the immediate subclasses of an ontology class. Use for 'what are the direct children of X'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "PARENT_CONCEPT": { "type": "string", "description": "An ontology class name" }
          },
          "required": ["PARENT_CONCEPT"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_hierarchy_path_tool",
        "description": "Return the subClassOf path between two ontology classes. Use for 'what is the path from X to Y in the class hierarchy'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "START_CONCEPT": { "type": "string", "description": "Starting ontology class name" },
            "END_CONCEPT": { "type": "string", "description": "Target ancestor class name" }
          },
          "required": ["START_CONCEPT", "END_CONCEPT"]
        }
      }
    }
  ],
  "tool_resources": {
    "base_query_tool": {
      "semantic_view": "FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_BASE",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299 }
    },
    "kg_query_tool": {
      "semantic_view": "FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_KG_MODEL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299 }
    },
    "ontology_query_tool": {
      "semantic_view": "FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_ONTOLOGY_MODEL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299 }
    },
    "metadata_query_tool": {
      "semantic_view": "FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_METADATA_MODEL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299 }
    },
    "catalog_search_tool": {
      "search_service": "FDA_DEVICES.ONTOLOGY.CSS_DEVICE_CATALOG",
      "max_results": 5,
      "id_column": "CATALOG_ID",
      "title_column": "DEVICE_NAME"
    },
    "get_ancestors_tool": {
      "type": "function",
      "identifier": "FDA_DEVICES.ONTOLOGY.GET_ANCESTORS_TOOL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 120 }
    },
    "expand_descendants_tool": {
      "type": "function",
      "identifier": "FDA_DEVICES.ONTOLOGY.EXPAND_DESCENDANTS_TOOL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 120 }
    },
    "get_direct_children_tool": {
      "type": "function",
      "identifier": "FDA_DEVICES.ONTOLOGY.GET_DIRECT_CHILDREN_TOOL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 120 }
    },
    "get_hierarchy_path_tool": {
      "type": "function",
      "identifier": "FDA_DEVICES.ONTOLOGY.GET_HIERARCHY_PATH_TOOL",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 120 }
    }
  }
}
$$;

-- --------------------------------------------------------------------------
-- Baseline agent (base semantic view only - no ontology resolution)
-- --------------------------------------------------------------------------
CREATE OR REPLACE AGENT FDA_DEVICES.ONTOLOGY.MMD_BASE_AGENT
COMMENT = 'Baseline MMD agent using ONLY the base semantic view (raw source tables, no ontology resolution) - for comparison'
PROFILE = '{"display_name": "MMD Base Agent (baseline)", "color": "gray"}'
FROM SPECIFICATION
$$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You answer questions about medical device data by querying the source tables via the base semantic view. The data spans three source systems loaded as raw tables: FDA device registry (DEVICE_RECORD with GUDID identifiers, manufacturer names, model numbers, device descriptions, and classifications), Trimedx master catalog (DEVICE_CATALOG, MANUFACTURER, DEVICE_FAMILY, PM_SCHEDULE, SERVICE_COST_ESTIMATE), and incoming site inventory (EQUIPMENT_LIST, SITE_INFO, DEPARTMENT). Use the base_query_tool for all questions. Answer strictly from what the tool returns.",
    "response": "Be concise. Present multi-row results as markdown tables. If the data needed to answer is split across source systems under different identifiers, manufacturer names, or model numbers, answer with what the base tables directly support and state any limitation. For example, if a site's equipment uses a manufacturer name that does not exactly match the Trimedx or FDA records, note that the join fails and the cost cannot be estimated."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "base_query_tool",
        "description": "Query the raw MMD source tables via the MMD_ONTOLOGY_BASE semantic view: FDA registry (DEVICE_RECORD), Trimedx master (DEVICE_CATALOG, MANUFACTURER, DEVICE_FAMILY, PM_SCHEDULE, SERVICE_COST_ESTIMATE), and site inventory (EQUIPMENT_LIST, SITE_INFO, DEPARTMENT). Relationships exist within each source system via foreign keys. Cross-system joins depend on exact key matches (FDA_DI for FDA-to-catalog, MFR_ID for catalog-to-manufacturer)."
      }
    }
  ],
  "tool_resources": {
    "base_query_tool": {
      "semantic_view": "FDA_DEVICES.ONTOLOGY.MMD_ONTOLOGY_BASE",
      "execution_environment": { "type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299 }
    }
  }
}
$$;
