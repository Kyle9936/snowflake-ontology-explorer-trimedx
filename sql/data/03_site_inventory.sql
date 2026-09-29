/* =============================================================================
   SYSTEM 3 of 3:  SITE_INVENTORY  (raw incoming equipment list from a new site)
   -----------------------------------------------------------------------------
   Demo purpose: messy source data for an MMD ontology-alignment demo.

   This system's vocabulary:
     - A device is an "EQUIPMENT_LIST" entry (free-text, unstructured)
     - Locations are "DEPARTMENT" names (inconsistent with Trimedx conventions)
     - There is NO manufacturer master - just free-text fields
     - There is NO model master - just free-text fields
     - Service history is embedded in the same row (overloaded)

   Intentional messiness in this file:
     1. MANUFACTURER field uses every imaginable abbreviation and variant:
        "GE", "G.E.", "Gen Electric", "GE Med Sys", etc.
     2. MODEL field is wildly inconsistent: sometimes includes the brand name,
        sometimes just a number, sometimes has typos.
     3. DEVICE_DESCRIPTION is free-text from the site's CMMS export - may be
        truncated, abbreviated, or use non-standard terminology.
     4. Some rows are OVERLOADED: device + location + last PM date + condition
        all crammed into one record with no normalization.
     5. SERIAL_NUMBER is sometimes missing, sometimes formatted differently.
     6. ~15% of records are deliberately hard to match:
        - misspelled manufacturer names
        - model numbers with extra/missing characters
        - descriptions that use colloquial terms ("vent" not "ventilator")
     7. NO FDA identifiers, NO Trimedx catalog IDs - this is raw site data.

   Cross-system linkage keys:
     - MANUFACTURER      -> fuzzy match to FDA COMPANY_NAME and TRIMEDX MFR_NAME
     - MODEL             -> fuzzy match to FDA VERSION_MODEL_NUMBER and TRIMEDX MODEL_NUMBER
     - DEVICE_DESCRIPTION -> fuzzy match to other systems' descriptions
     - SERIAL_NUMBER     -> unique per physical device instance (not in other systems' catalog)
   =============================================================================*/

CREATE DATABASE IF NOT EXISTS SITE_INVENTORY;
CREATE SCHEMA   IF NOT EXISTS SITE_INVENTORY.RAW;
USE SCHEMA SITE_INVENTORY.RAW;

-- -----------------------------------------------------------------------------
-- SITE_INFO  (the hospital site being onboarded)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SITE_INFO (
    SITE_ID         NUMBER,
    SITE_NAME       STRING,
    SITE_TYPE       STRING,       -- HOSPITAL / SURGERY_CENTER / CLINIC
    BED_COUNT       NUMBER,
    ADDRESS         STRING,
    CITY            STRING,
    STATE           STRING,
    ZIP             STRING,
    ONBOARD_DATE    DATE
);

INSERT INTO SITE_INFO VALUES
(1,'Memorial Regional Medical Center','HOSPITAL',450,'1200 Healthcare Blvd','Indianapolis','IN','46202','2024-07-01');

-- -----------------------------------------------------------------------------
-- DEPARTMENT  (departments at the new site - naming doesn't match Trimedx conventions)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE DEPARTMENT (
    DEPT_ID         NUMBER,
    SITE_ID         NUMBER,
    DEPT_NAME       STRING,       -- site's own naming (inconsistent with Trimedx)
    FLOOR           STRING,
    WING            STRING
);

INSERT INTO DEPARTMENT VALUES
(101,1,'ICU','3','East'),
(102,1,'CCU','3','West'),
(103,1,'NICU','2','North'),
(104,1,'Emergency Dept','1','Main'),
(105,1,'OR Suite 1','2','South'),
(106,1,'OR Suite 2','2','South'),
(107,1,'Radiology','1','West'),
(108,1,'Cath Lab','2','East'),
(109,1,'Labor and Delivery','2','North'),
(110,1,'Med/Surg 4A','4','East'),
(111,1,'Med/Surg 4B','4','West'),
(112,1,'Respiratory Therapy','3','Central'),
(113,1,'Endoscopy','1','South'),
(114,1,'Sterile Processing','B1','Central'),
(115,1,'Lab','1','East'),
(116,1,'Outpatient Clinic','1','North');

-- -----------------------------------------------------------------------------
-- EQUIPMENT_LIST  (the messy raw inventory export from the site's CMMS)
-- This is what Trimedx receives and must match to their MMD catalog.
-- OVERLOADED: device + location + service history in one row.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE EQUIPMENT_LIST (
    EQUIP_ID        NUMBER,
    SITE_ID         NUMBER,
    DEPT_ID         NUMBER,
    MANUFACTURER    STRING,       -- free-text, wildly inconsistent
    MODEL           STRING,       -- free-text, may include brand or just a number
    DEVICE_DESCRIPTION STRING,    -- free-text, abbreviated, colloquial
    SERIAL_NUMBER   STRING,       -- sometimes missing or formatted oddly
    ASSET_TAG       STRING,       -- site's internal asset tag
    INSTALL_DATE    DATE,
    LAST_PM_DATE    DATE,         -- embedded service history
    CONDITION       STRING,       -- GOOD / FAIR / POOR / UNKNOWN
    STATUS          STRING        -- IN_SERVICE / OUT_OF_SERVICE / SPARE / DECOMMISSIONED
);

INSERT INTO EQUIPMENT_LIST VALUES
-- ===== ICU (dept 101) - ~15 devices =====
-- Easy matches (manufacturer/model close to Trimedx catalog)
(1,1,101,'GE Healthcare','B650','Patient Monitor','SN-GE-B650-001','MR-10001','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),
(2,1,101,'GE Healthcare','B650','Patient Monitor','SN-GE-B650-002','MR-10002','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),
(3,1,101,'GE','B850','Bedside Monitor - Critical Care','SN-GE-B850-001','MR-10003','2022-06-10','2024-02-15','GOOD','IN_SERVICE'),
-- Hard match: abbreviated manufacturer, model with extra text
(4,1,101,'Phil','IntelliVue MX800','ICU Monitor','SN-PH-MX800-001','MR-10004','2020-11-01','2023-11-05','GOOD','IN_SERVICE'),
(5,1,101,'Phil Medical','MX800','Monitor','SN-PH-MX800-002','MR-10005','2020-11-01','2023-11-05','FAIR','IN_SERVICE'),
-- Hard match: misspelled manufacturer
(6,1,101,'Masiom','Root','Pulse Ox Platform',NULL,'MR-10006','2023-01-20','2024-01-20','GOOD','IN_SERVICE'),
(7,1,101,'Masimo','Radical 7','SpO2 Monitor','SN-MA-R7-001','MR-10007','2022-04-15','2024-04-15','GOOD','IN_SERVICE'),
-- Ventilators with colloquial descriptions
(8,1,101,'Draeger','V800','Vent - ICU','SN-DR-V800-001','MR-10008','2021-09-01','2024-03-01','GOOD','IN_SERVICE'),
(9,1,101,'Drager','Evita V800','ICU Ventilator','SN-DR-V800-002','MR-10009','2021-09-01','2024-03-01','GOOD','IN_SERVICE'),
(10,1,101,'Hamilton','C6','Vent','SN-HM-C6-001','MR-10010','2023-05-10','2024-05-10','GOOD','IN_SERVICE'),
-- Legacy device with vague description
(11,1,101,'Medtronic','PB 840','Ventilator (old)','SN-MT-PB840-001','MR-10011','2015-08-20','2023-08-20','POOR','IN_SERVICE'),
-- Infusion pumps
(12,1,101,'BD','Alaris 8015','IV Pump','SN-BD-AL-001','MR-10012','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),
(13,1,101,'BD','Alaris 8015','IV Pump','SN-BD-AL-002','MR-10013','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),
(14,1,101,'BD','Alaris 8015','IV Pump','SN-BD-AL-003','MR-10014','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),
(15,1,101,'Hill-Rom','Centrella','Hospital Bed','SN-HR-CEN-001','MR-10015','2020-05-10','2024-05-10','FAIR','IN_SERVICE'),

-- ===== CCU (dept 102) - ~10 devices =====
(16,1,102,'GE','Carescape B650','CCU Monitor','SN-GE-B650-003','MR-10016','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),
(17,1,102,'GE','Carescape B650','CCU Monitor','SN-GE-B650-004','MR-10017','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),
(18,1,102,'Philips','HeartStart MRx','Defib','SN-PH-MRX-001','MR-10018','2019-10-01','2023-10-01','FAIR','IN_SERVICE'),
(19,1,102,'ZOLL','R Series','Defibrillator/Monitor','SN-ZL-RS-001','MR-10019','2022-08-15','2024-02-15','GOOD','IN_SERVICE'),
(20,1,102,'Getinge','Servo U','Vent','SN-GT-SU-001','MR-10020','2023-01-15','2024-01-15','GOOD','IN_SERVICE'),
(21,1,102,'Baxter','Spectrum IQ','Infusion Pump','SN-BX-SIQ-001','MR-10021','2022-06-01','2024-06-01','GOOD','IN_SERVICE'),
(22,1,102,'Baxter','Spectrum IQ','Infusion Pump','SN-BX-SIQ-002','MR-10022','2022-06-01','2024-06-01','GOOD','IN_SERVICE'),
(23,1,102,'Baxter','Spectrum IQ','Infusion Pump','SN-BX-SIQ-003','MR-10023','2022-06-01','2024-06-01','GOOD','IN_SERVICE'),
(24,1,102,'Hill-Rom','Centrella Smart+','Bed','SN-HR-CEN-002','MR-10024','2020-05-10','2024-05-10','GOOD','IN_SERVICE'),
(25,1,102,'Hill-Rom','Centrella Smart+','Bed','SN-HR-CEN-003','MR-10025','2020-05-10','2024-05-10','GOOD','IN_SERVICE'),

-- ===== NICU (dept 103) - ~8 devices =====
(26,1,103,'Draeger','Babylog VN800','Neo Vent','SN-DR-VN800-001','MR-10026','2022-01-10','2024-01-10','GOOD','IN_SERVICE'),
(27,1,103,'Drager Medical','VN800','Neonatal Ventilator','SN-DR-VN800-002','MR-10027','2022-01-10','2024-01-10','GOOD','IN_SERVICE'),
-- Hard match: "Drager" vs "Draeger" and different model reference
(28,1,103,'Drager','Isolette C2000','Incubator','SN-DR-C2K-001','MR-10028','2021-06-15','2024-06-15','GOOD','IN_SERVICE'),
(29,1,103,'Draeger','C2000','Baby Incubator','SN-DR-C2K-002','MR-10029','2021-06-15','2024-06-15','GOOD','IN_SERVICE'),
(30,1,103,'GE','Carescape B650','NICU Monitor','SN-GE-B650-005','MR-10030','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),
(31,1,103,'Masimo','Rad-97','Pulse Ox','SN-MA-R97-001','MR-10031','2022-11-01','2023-11-01','GOOD','IN_SERVICE'),
(32,1,103,'BD','Alaris 8015','IV Pump','SN-BD-AL-004','MR-10032','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),
(33,1,103,'Natus','ALGO 5','Hearing Screener','SN-NA-A5-001','MR-10033','2021-11-15','2023-11-15','GOOD','IN_SERVICE'),

-- ===== Emergency Dept (dept 104) - ~12 devices =====
(34,1,104,'GE Med Sys','XR240amx','Portable X-ray','SN-GE-XR240-001','MR-10034','2021-06-20','2024-06-20','GOOD','IN_SERVICE'),
-- Hard match: "GE Med Sys" is a rare abbreviation
(35,1,104,'ZOLL','AED 3','AED','SN-ZL-AED3-001','MR-10035','2022-01-28','2024-01-28','GOOD','IN_SERVICE'),
(36,1,104,'ZOLL','AED 3','AED','SN-ZL-AED3-002','MR-10036','2022-01-28','2024-01-28','GOOD','IN_SERVICE'),
(37,1,104,'ZOLL','R Series Plus','Defib/Monitor','SN-ZL-RS-002','MR-10037','2022-08-15','2024-02-15','GOOD','IN_SERVICE'),
(38,1,104,'Philips','X3','Transport Monitor','SN-PH-X3-001','MR-10038','2022-07-12','2024-01-12','GOOD','IN_SERVICE'),
(39,1,104,'Philips','IntelliVue X3','Transport Mon','SN-PH-X3-002','MR-10039','2022-07-12','2024-01-12','GOOD','IN_SERVICE'),
(40,1,104,'Hamilton Medical','T1','Transport Vent','SN-HM-T1-001','MR-10040','2023-06-25','2024-06-25','GOOD','IN_SERVICE'),
(41,1,104,'Welch Allyn','Spot 4400','Vitals','SN-WA-4400-001','MR-10041','2021-09-20','2024-03-20','GOOD','IN_SERVICE'),
(42,1,104,'Welch Allyn','VSM 4400','Vital Signs','SN-WA-4400-002','MR-10042','2021-09-20','2024-03-20','GOOD','IN_SERVICE'),
-- Hard match: Welch Allyn is now Hill-Rom, model naming differs
(43,1,104,'Teleflex','EZ-IO','IO Access Device','SN-TF-EZIO-001','MR-10043','2022-09-28','2024-03-28','GOOD','IN_SERVICE'),
(44,1,104,'Masimo','Root','Monitoring Hub','SN-MA-RT-001','MR-10044','2023-04-05','2024-04-05','GOOD','IN_SERVICE'),
(45,1,104,'BD','Alaris 8015','IV Pump','SN-BD-AL-005','MR-10045','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),

-- ===== OR Suite 1 (dept 105) - ~12 devices =====
(46,1,105,'Draeger','Perseus A500','Anesthesia Machine','SN-DR-A500-001','MR-10046','2022-09-22','2024-03-22','GOOD','IN_SERVICE'),
-- Hard match: "Getinge" vs "Maquet" (Getinge acquired Maquet)
(47,1,105,'Maquet','FLOW-i','Anesthesia Workstation','SN-MQ-FI-001','MR-10047','2022-03-08','2024-03-08','GOOD','IN_SERVICE'),
(48,1,105,'Stryker','System 8','Sagittal Saw','SN-SK-S8S-001','MR-10048','2023-01-18','2024-01-18','GOOD','IN_SERVICE'),
(49,1,105,'Stryker','System 8','Power Drill','SN-SK-S8D-001','MR-10049','2023-01-18','2024-01-18','GOOD','IN_SERVICE'),
(50,1,105,'Stryker','Neptune 3','Waste Mgmt','SN-SK-N3-001','MR-10050','2023-03-08','2024-03-08','GOOD','IN_SERVICE'),
-- Hard match: "Covidien" is now Medtronic
(51,1,105,'Covidien','FT10','ESU','SN-CV-FT10-001','MR-10051','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),
(52,1,105,'Medtronic','BIS VISTA','Brain Monitor','SN-MT-BIS-001','MR-10052','2021-08-16','2024-02-16','GOOD','IN_SERVICE'),
(53,1,105,'Steris','Harmony aIR 600','Surg Light','SN-ST-HA-001','MR-10053','2023-03-22','2024-03-22','GOOD','IN_SERVICE'),
(54,1,105,'Steris','Harmony aIR 600','Surg Light','SN-ST-HA-002','MR-10054','2023-03-22','2024-03-22','GOOD','IN_SERVICE'),
(55,1,105,'Stryker','1288 HD','Endo Camera','SN-SK-1288-001','MR-10055','2022-04-12','2024-04-12','GOOD','IN_SERVICE'),
-- Hard match: "Howmedica" is a Stryker subsidiary
(56,1,105,'Getinge','Tegris','OR Video System','SN-GT-TG-001','MR-10056','2022-08-14','2024-02-14','GOOD','IN_SERVICE'),
(57,1,105,'GE','Carescape B650','OR Monitor','SN-GE-B650-006','MR-10057','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),

-- ===== OR Suite 2 (dept 106) - ~10 devices =====
(58,1,106,'GE Healthcare','Engstrom','Anesthesia System','SN-GE-ENG-001','MR-10058','2022-04-18','2024-04-18','GOOD','IN_SERVICE'),
-- Hard match: just "Engstrom" without "Carestation"
(59,1,106,'Stryker','System 8','Reciprocating Saw','SN-SK-S8R-001','MR-10059','2023-01-18','2024-01-18','GOOD','IN_SERVICE'),
(60,1,106,'Smith & Nephew','CORI','Surgical Robot','SN-SN-CORI-001','MR-10060','2024-04-12',NULL,'GOOD','IN_SERVICE'),
(61,1,106,'Smith Nephew','DYONICS POWER II','Shaver','SN-SN-DP2-001','MR-10061','2022-01-05','2024-01-05','GOOD','IN_SERVICE'),
-- Hard match: "Smith Nephew" without ampersand or plus
(62,1,106,'Smith+Nephew','1000XL','4K Camera','SN-SN-1KXL-001','MR-10062','2022-07-18','2024-01-18','GOOD','IN_SERVICE'),
(63,1,106,'Medtronic','StealthStation S8','Surgical Nav','SN-MT-SS8-001','MR-10063','2023-05-01','2024-05-01','GOOD','IN_SERVICE'),
(64,1,106,'Steris','V-160H','Sterilizer','SN-ST-V160-001','MR-10064','2022-08-01','2024-02-01','GOOD','IN_SERVICE'),
(65,1,106,'Steris','Harmony aIR','OR Light','SN-ST-HA-003','MR-10065','2023-03-22','2024-03-22','GOOD','IN_SERVICE'),
(66,1,106,'Covidien','Nellcor PM1000N','Pulse Ox','SN-CV-PM1K-001','MR-10066','2021-03-22','2024-03-22','GOOD','IN_SERVICE'),
(67,1,106,'BD','Alaris 8015','IV Pump','SN-BD-AL-006','MR-10067','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),

-- ===== Radiology (dept 107) - ~12 devices =====
(68,1,107,'GE','Revolution EVO','CT Scanner','SN-GE-REVO-001','MR-10068','2023-05-22','2024-05-22','GOOD','IN_SERVICE'),
(69,1,107,'Siemens','SOMATOM Force','CT - Dual Source','SN-SI-FORCE-001','MR-10069','2023-03-01','2024-03-01','GOOD','IN_SERVICE'),
-- Hard match: "Siemens" not "Siemens Healthineers"
(70,1,107,'Siemens Healthineers','go.Top','CT Scanner','SN-SI-GOTOP-001','MR-10070','2022-08-30','2024-02-28','GOOD','IN_SERVICE'),
(71,1,107,'Siemens','MAGNETOM Vida','MRI 3T','SN-SI-VIDA-001','MR-10071','2022-06-15','2024-06-15','GOOD','IN_SERVICE'),
(72,1,107,'Canon','Aquilion ONE','CT 320-row','SN-CN-ONE-001','MR-10072','2023-06-01','2024-06-01','GOOD','IN_SERVICE'),
-- Hard match: "Canon" not "Canon Medical Systems Corporation"
(73,1,107,'Toshiba','Aquilion Prime','CT','SN-TS-PRIME-001','MR-10073','2020-02-14','2024-02-14','FAIR','IN_SERVICE'),
-- Hard match: Toshiba is now Canon Medical
(74,1,107,'Siemens','Ysio Max','DR System','SN-SI-YSIO-001','MR-10074','2021-11-28','2024-05-28','GOOD','IN_SERVICE'),
(75,1,107,'Siemens','Mobilett Elara','Mobile X-ray','SN-SI-ELARA-001','MR-10075','2022-05-18','2024-05-18','GOOD','IN_SERVICE'),
(76,1,107,'Philips','DigitalDiagnost C90','Ceiling DR','SN-PH-DDC90-001','MR-10076','2022-03-25','2024-03-25','GOOD','IN_SERVICE'),
(77,1,107,'Fujifilm','D-EVO III','DR Detector','SN-FJ-DEVO-001','MR-10077','2023-01-12','2024-01-12','GOOD','IN_SERVICE'),
-- Hard match: "Fujifilm" not "Fujifilm Healthcare Americas"
(78,1,107,'Fuji','Capsula XLII','CR Reader','SN-FJ-CAP-001','MR-10078','2019-05-30','2024-05-30','POOR','IN_SERVICE'),
-- Hard match: "Fuji" is abbreviation, and this is a legacy system
(79,1,107,'Hologic','Selenia Dimensions','Mammo 3D','SN-HL-DIM-001','MR-10079','2022-07-08','2024-01-08','GOOD','IN_SERVICE'),

-- ===== Cath Lab (dept 108) - ~6 devices =====
(80,1,108,'Philips','Azurion 7','Interventional X-ray','SN-PH-AZ7-001','MR-10080','2023-01-30','2024-01-30','GOOD','IN_SERVICE'),
(81,1,108,'Siemens','Artis icono','Angio System','SN-SI-ARTIS-001','MR-10081','2022-12-10','2024-06-10','GOOD','IN_SERVICE'),
(82,1,108,'GE','Vivid E95','Echo Machine','SN-GE-E95-001','MR-10082','2022-11-01','2024-05-01','GOOD','IN_SERVICE'),
(83,1,108,'Philips','EPIQ Elite','Echo Ultrasound','SN-PH-EPIQ-001','MR-10083','2023-04-01','2024-04-01','GOOD','IN_SERVICE'),
(84,1,108,'Siemens','SC2000','Cardiac US','SN-SI-SC2K-001','MR-10084','2023-02-14','2024-02-14','GOOD','IN_SERVICE'),
(85,1,108,'GE','Venue Go','POCUS','SN-GE-VGO-001','MR-10085','2023-01-10','2024-01-10','GOOD','IN_SERVICE'),

-- ===== Labor and Delivery (dept 109) - ~6 devices =====
(86,1,109,'GE','Voluson E10','OB Ultrasound','SN-GE-VOL-001','MR-10086','2021-09-14','2024-03-14','GOOD','IN_SERVICE'),
(87,1,109,'Gen Electric','LOGIQ E10s','Ultrasound','SN-GE-E10S-001','MR-10087','2022-08-05','2024-02-05','GOOD','IN_SERVICE'),
-- Hard match: "Gen Electric" is a rare abbreviation
(88,1,109,'GE','Carescape B650','Labor Delivery Monitor','SN-GE-B650-007','MR-10088','2021-03-15','2024-01-20','GOOD','IN_SERVICE'),
(89,1,109,'GE','Engstrom Carestation','Anesthesia','SN-GE-ENG-002','MR-10089','2022-04-18','2024-04-18','GOOD','IN_SERVICE'),
(90,1,109,'Masimo','Root','Pulse Ox Station','SN-MA-RT-002','MR-10090','2023-04-05','2024-04-05','GOOD','IN_SERVICE'),
(91,1,109,'BD','Alaris 8015','IV Pump','SN-BD-AL-007','MR-10091','2022-07-01','2024-01-01','GOOD','IN_SERVICE'),

-- ===== Med/Surg 4A (dept 110) - ~8 devices =====
(92,1,110,'Mindray','BeneVision N22','Bedside Monitor','SN-MR-N22-001','MR-10092','2023-02-20','2024-02-20','GOOD','IN_SERVICE'),
(93,1,110,'Mindray','N22','Monitor','SN-MR-N22-002','MR-10093','2023-02-20','2024-02-20','GOOD','IN_SERVICE'),
-- Mindray with and without brand prefix
(94,1,110,'Baxter','Spectrum','Infusion Pump','SN-BX-SIQ-004','MR-10094','2022-06-01','2024-06-01','GOOD','IN_SERVICE'),
-- Hard match: "Spectrum" without "IQ" or "SIGMA"
(95,1,110,'Baxter','Spectrum','Infusion Pump','SN-BX-SIQ-005','MR-10095','2022-06-01','2024-06-01','GOOD','IN_SERVICE'),
(96,1,110,'Hill-Rom','Centrella','Bed, Electric','SN-HR-CEN-004','MR-10096','2020-05-10','2024-05-10','FAIR','IN_SERVICE'),
(97,1,110,'Hill-Rom','Centrella','Bed, Electric','SN-HR-CEN-005','MR-10097','2020-05-10','2024-05-10','FAIR','IN_SERVICE'),
(98,1,110,'Welch Allyn','Connex VSM','Vital Signs','SN-WA-6000-001','MR-10098','2022-05-30','2024-05-30','GOOD','IN_SERVICE'),
-- Hard match: "Connex VSM" without "6000"
(99,1,110,'Medtronic','Kangaroo','Feeding Pump','SN-MT-KNG-001','MR-10099','2022-02-20','2024-02-20','GOOD','IN_SERVICE'),
-- Hard match: "Kangaroo" without "ePump"

-- ===== Med/Surg 4B (dept 111) - ~6 devices =====
(100,1,111,'Mindray','BeneVision N22','Bedside Monitor','SN-MR-N22-003','MR-10100','2023-02-20','2024-02-20','GOOD','IN_SERVICE'),
(101,1,111,'Mindray','N22','Mon','SN-MR-N22-004','MR-10101','2023-02-20','2024-02-20','GOOD','IN_SERVICE'),
(102,1,111,'Baxter','Spectrum IQ','Pump','SN-BX-SIQ-006','MR-10102','2022-06-01','2024-06-01','GOOD','IN_SERVICE'),
(103,1,111,'Hill-Rom','Centrella','Bed','SN-HR-CEN-006','MR-10103','2020-05-10','2024-05-10','POOR','IN_SERVICE'),
(104,1,111,'Welch Allyn','Spot 4400','Vitals','SN-WA-4400-003','MR-10104','2021-09-20','2024-03-20','GOOD','IN_SERVICE'),
(105,1,111,'Medtronic','Kangaroo ePump','Feeding Pump','SN-MT-KNG-002','MR-10105','2022-02-20','2024-02-20','GOOD','IN_SERVICE'),

-- ===== Respiratory Therapy (dept 112) - ~8 devices =====
(106,1,112,'Medtronic','PB 980','ICU Vent','SN-MT-PB980-001','MR-10106','2022-11-15','2024-05-15','GOOD','IN_SERVICE'),
-- Hard match: "PB 980" with space vs "PB980"
(107,1,112,'Medtronic','Puritan Bennett 980','Ventilator','SN-MT-PB980-002','MR-10107','2022-11-15','2024-05-15','GOOD','IN_SERVICE'),
(108,1,112,'Philips','V680','Resp Vent','SN-PH-V680-001','MR-10108','2023-06-11','2024-06-11','GOOD','IN_SERVICE'),
(109,1,112,'Mindray','SV300','Vent','SN-MR-SV300-001','MR-10109','2022-04-22','2024-04-22','GOOD','IN_SERVICE'),
-- Hard match: "Vyaire" brand confusion - CareFusion legacy
(110,1,112,'CareFusion','AVEA','Vent - Legacy','SN-CF-AVEA-001','MR-10110','2019-07-15','2024-01-15','POOR','IN_SERVICE'),
-- Hard match: "CareFusion" was acquired by BD, AVEA is now BD/legacy
(111,1,112,'Vyaire','AVEA CVS','Ventilator','SN-VY-AVEA-001','MR-10111','2022-06-14','2024-06-14','GOOD','IN_SERVICE'),
(112,1,112,'Medtronic','Capnostream 35','Capnography','SN-MT-CS35-001','MR-10112','2022-10-05','2024-04-05','GOOD','IN_SERVICE'),
(113,1,112,'Vyaire','MasterScreen PFT','Lung Function','SN-VY-MSPFT-001','MR-10113','2021-08-22','2024-02-22','GOOD','IN_SERVICE'),

-- ===== Endoscopy (dept 113) - ~8 devices =====
(114,1,113,'Olympus','EVIS X1','Video Processor','SN-OL-X1-001','MR-10114','2023-02-28','2024-02-28','GOOD','IN_SERVICE'),
(115,1,113,'Olympus','CV-1500','Endoscopy Processor','SN-OL-CV1500-001','MR-10115','2023-02-28','2024-02-28','GOOD','IN_SERVICE'),
-- Hard match: EVIS X1 and CV-1500 are the same device (brand vs model)
(116,1,113,'Olympus','TJF-Q190V','Duodenoscope','SN-OL-Q190V-001','MR-10116','2022-05-14','2024-05-14','GOOD','IN_SERVICE'),
(117,1,113,'Olympus','GIF-HQ190','Gastroscope','SN-OL-HQ190-001','MR-10117','2022-11-08','2024-05-08','GOOD','IN_SERVICE'),
(118,1,113,'Olympus','GIF-HQ190','Gastroscope','SN-OL-HQ190-002','MR-10118','2022-11-08','2024-05-08','GOOD','IN_SERVICE'),
(119,1,113,'GE','Venue Go','POCUS','SN-GE-VGO-002','MR-10119','2023-01-10','2024-01-10','GOOD','IN_SERVICE'),
(120,1,113,'Phil','CX50','Ultrasound','SN-PH-CX50-001','MR-10120','2021-12-15','2024-06-15','GOOD','IN_SERVICE'),
(121,1,113,'Stryker','1288 HD','Endo Camera','SN-SK-1288-002','MR-10121','2022-04-12','2024-04-12','GOOD','IN_SERVICE'),

-- ===== Sterile Processing (dept 114) - ~3 devices =====
(122,1,114,'Steris','Century V-160H','Steam Sterilizer','SN-ST-V160-002','MR-10122','2022-08-01','2024-02-01','GOOD','IN_SERVICE'),
(123,1,114,'STERIS','V-160H','Autoclave','SN-ST-V160-003','MR-10123','2022-08-01','2024-02-01','GOOD','IN_SERVICE'),
-- Different manufacturer casing and device description
(124,1,114,'Steris','V-160H','Steam Sterilizer','SN-ST-V160-004','MR-10124','2022-08-01','2024-02-01','FAIR','IN_SERVICE'),

-- ===== Lab (dept 115) - ~4 devices =====
(125,1,115,'Siemens','Atellica','Chemistry Analyzer','SN-SI-ATEL-001','MR-10125','2023-01-05','2024-01-05','GOOD','IN_SERVICE'),
(126,1,115,'BD','Veritor Plus','Rapid Test Analyzer','SN-BD-VER-001','MR-10126','2022-03-14','2024-03-14','GOOD','IN_SERVICE'),
(127,1,115,'Baxter','PrisMax','CRRT System','SN-BX-PM-001','MR-10127','2023-02-05','2024-02-05','GOOD','IN_SERVICE'),
(128,1,115,'Baxter','HomeChoice Claria','PD Cycler','SN-BX-CLR-001','MR-10128','2022-08-18','2024-02-18','GOOD','IN_SERVICE'),

-- ===== Outpatient Clinic (dept 116) - ~10 devices =====
(129,1,116,'GE','LOGIQ E10s','Ultrasound','SN-GE-E10S-002','MR-10129','2022-08-05','2024-02-05','GOOD','IN_SERVICE'),
(130,1,116,'Canon Medical','Aplio i800','Ultrasound','SN-CN-I800-001','MR-10130','2022-07-20','2024-01-20','GOOD','IN_SERVICE'),
-- Hard match: "Canon Medical" not "Canon Medical Systems Corporation"
(131,1,116,'Toshiba Medical','Xario 200','US','SN-TS-X200-001','MR-10131','2019-04-10','2024-04-10','POOR','IN_SERVICE'),
-- Hard match: "Toshiba Medical" is legacy, now Canon
(132,1,116,'Mindray','Resona I9','Ultrasound','SN-MR-RI9-001','MR-10132','2023-05-28','2024-05-28','GOOD','IN_SERVICE'),
(133,1,116,'Nihon Kohden','Vismo PVM-4763','Monitor','SN-NK-PVM-001','MR-10133','2024-06-05',NULL,'GOOD','IN_SERVICE'),
(134,1,116,'Hill-Rom','RetinaVue 700','Eye Camera','SN-HR-RV700-001','MR-10134','2021-12-08','2024-06-08','GOOD','IN_SERVICE'),
(135,1,116,'Nihon Kohden','WEE-1000','EEG','SN-NK-WEE-001','MR-10135','2022-10-30','2024-04-30','GOOD','IN_SERVICE'),
(136,1,116,'Spacelabs','Xprezzon','Bedside Monitor','SN-SL-XPR-001','MR-10136','2022-04-05','2024-04-05','GOOD','IN_SERVICE'),
(137,1,116,'ZOLL','Thermogard','Temp Management','SN-ZL-TGXP-001','MR-10137','2023-03-18','2024-03-18','GOOD','IN_SERVICE'),
-- Hard match: "Thermogard" without "XP"
(138,1,116,'BD','Pyxis MedStation','Med Cabinet','SN-BD-PYX-001','MR-10138','2022-12-01','2024-06-01','GOOD','IN_SERVICE'),

-- ===== Devices with NO match possible (should fail gracefully) =====
(139,1,104,'Unknown','Custom Defib','Custom Built Defibrillator',NULL,'MR-10139','2010-01-01','2020-01-01','POOR','DECOMMISSIONED'),
(140,1,110,'Acme Medical','FP-100','Floor Pump',NULL,'MR-10140','2012-06-01','2022-06-01','POOR','OUT_OF_SERVICE');

-- Delete the old healthcare source files (they'll be replaced by the above)
-- Note: the old files remain on disk but are no longer referenced by deploy.sh
