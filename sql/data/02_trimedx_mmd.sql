/* =============================================================================
   SYSTEM 2 of 3:  TRIMEDX_MMD  (the proprietary master device catalog)
   -----------------------------------------------------------------------------
   Demo purpose: messy source data for an MMD ontology-alignment demo.

   This system's vocabulary:
     - A manufacturer is a "MANUFACTURER" (with a canonical MFR_ID)
     - A device is a "DEVICE_CATALOG" entry (Make + Model + Description)
     - A grouping is a "DEVICE_FAMILY" (logical grouping for pricing/service)
     - Parts are in "PART_CATALOG" (linked to device catalog entries)
     - Maintenance templates are in "PM_SCHEDULE" (linked to device catalog)
     - Cost estimates are in "SERVICE_COST_ESTIMATE" (annual cost per device)

   Intentional messiness in this file:
     1. MFR_NAME uses Trimedx-internal abbreviations that don't match FDA or
        site inventory naming ("GE" not "GE Healthcare", "Phil" not "Philips").
     2. MODEL_NUMBER sometimes differs from FDA VERSION_MODEL_NUMBER
        (no revision suffixes, different formatting).
     3. DEVICE_DESCRIPTION is abbreviated commercial shorthand, not FDA verbose.
     4. Some DEVICE_CATALOG entries have NULL FDA_DI (no FDA linkage).
     5. DEVICE_FAMILY groups devices that the other systems have no concept of.
     6. PART_CATALOG has internal part numbers that don't match OEM catalog numbers.

   Cross-system linkage keys:
     - FDA_DI              -> direct link to FDA_DEVICES.GUDID.DEVICE_RECORD.GUDID_DI
     - MFR_NAME            -> fuzzy match to FDA COMPANY_NAME and site MANUFACTURER
     - MODEL_NUMBER        -> fuzzy match to FDA VERSION_MODEL_NUMBER and site MODEL
     - OEM_PART_NUMBER     -> sometimes matches FDA CATALOG_NUMBER
   =============================================================================*/

CREATE DATABASE IF NOT EXISTS TRIMEDX_MMD;
CREATE SCHEMA   IF NOT EXISTS TRIMEDX_MMD.MASTER;
USE SCHEMA TRIMEDX_MMD.MASTER;

-- -----------------------------------------------------------------------------
-- MANUFACTURER  (canonical manufacturer list with Trimedx-internal IDs)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE MANUFACTURER (
    MFR_ID          NUMBER,
    MFR_NAME        STRING,       -- Trimedx abbreviation (differs from FDA)
    MFR_FULL_NAME   STRING,       -- longer form (still may differ from FDA)
    MFR_COUNTRY     STRING,
    ACTIVE_FLAG     BOOLEAN
);

INSERT INTO MANUFACTURER VALUES
(1,'GE','GE Healthcare Systems','United States',TRUE),
(2,'Phil','Philips Medical','Netherlands',TRUE),
(3,'Siemens','Siemens Healthineers','Germany',TRUE),
(4,'Medtronic','Medtronic / Covidien','United States',TRUE),
(5,'Stryker','Stryker Corp','United States',TRUE),
(6,'Baxter','Baxter International','United States',TRUE),
(7,'Draeger','Draeger Medical','Germany',TRUE),
(8,'BD','Becton Dickinson / CareFusion','United States',TRUE),
(9,'Hill-Rom','Hill-Rom / Hillrom / Welch Allyn','United States',TRUE),
(10,'Canon','Canon Medical / Toshiba Medical','Japan',TRUE),
(11,'ZOLL','ZOLL Medical','United States',TRUE),
(12,'Masimo','Masimo Corp','United States',TRUE),
(13,'Mindray','Mindray Medical','China',TRUE),
(14,'Getinge','Getinge / Maquet','Sweden',TRUE),
(15,'Nihon Kohden','Nihon Kohden','Japan',TRUE),
(16,'Smith+Nephew','Smith and Nephew','United Kingdom',TRUE),
(17,'Olympus','Olympus Medical','Japan',TRUE),
(18,'Hamilton','Hamilton Medical','Switzerland',TRUE),
(19,'Spacelabs','Spacelabs Healthcare','United States',TRUE),
(20,'Steris','Steris Corporation','United States',TRUE),
(21,'Natus','Natus Medical','United States',TRUE),
(22,'Hologic','Hologic Inc','United States',TRUE),
(23,'Fujifilm','Fujifilm Healthcare','Japan',TRUE),
(24,'Teleflex','Teleflex Inc','United States',TRUE),
(25,'Vyaire','Vyaire Medical','United States',TRUE),
(26,'Welch Allyn','Welch Allyn / Hillrom','United States',TRUE);

-- -----------------------------------------------------------------------------
-- DEVICE_FAMILY  (logical groupings for pricing and service planning)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE DEVICE_FAMILY (
    FAMILY_ID       NUMBER,
    FAMILY_NAME     STRING,
    FAMILY_CATEGORY STRING,       -- broad category
    DESCRIPTION     STRING,
    AVG_USEFUL_LIFE_YEARS NUMBER  -- typical useful life for the family
);

INSERT INTO DEVICE_FAMILY VALUES
(1,'Bedside Monitors','Patient Monitoring','High-acuity bedside and transport monitors',8),
(2,'Transport Monitors','Patient Monitoring','Compact monitors for intra-hospital transport',7),
(3,'Diagnostic Ultrasound','Diagnostic Imaging','Cart-based and premium ultrasound systems',10),
(4,'Point-of-Care Ultrasound','Diagnostic Imaging','Portable and handheld ultrasound devices',6),
(5,'CT Scanners','Diagnostic Imaging','Computed tomography systems, all slice counts',12),
(6,'MRI Systems','Diagnostic Imaging','Magnetic resonance imaging systems',15),
(7,'Digital Radiography','Diagnostic Imaging','Fixed and mobile X-ray / DR systems',10),
(8,'Computed Radiography','Diagnostic Imaging','CR readers and cassette-based systems',8),
(9,'Anesthesia Machines','Respiratory / Anesthesia','Anesthesia delivery and workstation systems',12),
(10,'Critical Care Ventilators','Respiratory / Anesthesia','ICU ventilators, invasive and noninvasive',10),
(11,'Neonatal Ventilators','Respiratory / Anesthesia','Ventilators designed for neonatal patients',10),
(12,'Transport Ventilators','Respiratory / Anesthesia','Ventilators for intra-hospital and inter-facility transport',8),
(13,'Infusion Pumps','Drug Delivery','Large volume infusion pump systems',7),
(14,'Enteral Feeding Pumps','Drug Delivery','Enteral nutrition delivery systems',6),
(15,'Defibrillators','Emergency / Cardiac','Professional monitor/defibrillator units',8),
(16,'AEDs','Emergency / Cardiac','Automated external defibrillators',5),
(17,'Pulse Oximeters','Patient Monitoring','Standalone and tabletop SpO2 monitors',6),
(18,'Vital Signs Monitors','Patient Monitoring','Spot-check vital signs devices',7),
(19,'Electrosurgical Units','Surgical','High-frequency electrosurgical generators',10),
(20,'Powered Surgical Instruments','Surgical','Saws, drills, shavers for OR use',8),
(21,'Endoscopic Cameras','Surgical','HD and 4K endoscopic camera systems',7),
(22,'Endoscopes','Surgical','Flexible and rigid endoscopes',5),
(23,'Surgical Navigation','Surgical','Image-guided navigation platforms',10),
(24,'Surgical Robots','Surgical','Robotic-assisted surgical platforms',12),
(25,'Hospital Beds','Infrastructure','Electric hospital beds, standard and specialty',10),
(26,'Sterilizers','Infrastructure','Steam and low-temp sterilization systems',15),
(27,'Surgical Lights','Infrastructure','LED surgical and exam lighting',12),
(28,'Interventional X-ray','Diagnostic Imaging','Angiography and interventional suites',12),
(29,'Lab Analyzers','Laboratory','Chemistry, immunoassay, and hematology analyzers',10),
(30,'Temperature Management','Specialty','Patient warming and cooling systems',8),
(31,'Incubators','Neonatal','Infant incubators and radiant warmers',10),
(32,'PFT Systems','Pulmonary','Pulmonary function testing and spirometry',10),
(33,'Medication Dispensing','Pharmacy Automation','Automated dispensing cabinets',8),
(34,'OR Integration','Surgical','Video routing, documentation, and OR management',10),
(35,'Hearing Screeners','Specialty','Newborn and diagnostic hearing screening',7),
(36,'Mammography','Diagnostic Imaging','Digital mammography and tomosynthesis',10),
(37,'Fundus Cameras','Ophthalmology','Retinal imaging devices',8),
(38,'EEG Systems','Neurodiagnostic','Electroencephalography systems',10),
(39,'Vascular Access','Emergency','IO and specialized vascular access devices',5),
(40,'Waste Management','Surgical','Surgical waste and smoke evacuation',8);

-- -----------------------------------------------------------------------------
-- DEVICE_CATALOG  (the master MMD table - Make, Model, Description)
-- Each row is a device the service team knows how to price and maintain.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE DEVICE_CATALOG (
    CATALOG_ID      NUMBER,
    MFR_ID          NUMBER,       -- FK to MANUFACTURER
    FAMILY_ID       NUMBER,       -- FK to DEVICE_FAMILY
    MODEL_NUMBER    STRING,       -- Trimedx internal model designation
    DEVICE_NAME     STRING,       -- short commercial name
    DEVICE_DESC     STRING,       -- abbreviated description
    FDA_DI          STRING,       -- link to FDA GUDID (nullable - not all matched)
    FDA_CLASS       NUMBER,       -- mirrored from FDA when available
    STATUS          STRING,       -- ACTIVE / DISCONTINUED / LEGACY
    LAST_UPDATED    DATE
);

INSERT INTO DEVICE_CATALOG VALUES
-- GE devices (MFR_ID=1)
(1001,1,1,'B650','Carescape B650','Bedside patient monitor, multi-param','10050001',2,'ACTIVE','2024-01-15'),
(1002,1,1,'B850','Carescape B850','Critical care monitor, hemodynamic','10050002',2,'ACTIVE','2024-01-15'),
(1003,1,3,'E95','Vivid E95','Cardiac ultrasound, advanced quant',NULL,2,'ACTIVE','2023-11-01'),
(1004,1,7,'XR240','Optima XR240amx','Mobile DR system','10050004',2,'ACTIVE','2023-06-20'),
(1005,1,4,'VENUE-GO','Venue Go','POCUS, portable, AI-assisted','10050005',2,'ACTIVE','2024-01-10'),
(1006,1,3,'E10S','LOGIQ E10s','General imaging ultrasound','10050006',2,'ACTIVE','2023-08-05'),
(1007,1,5,'REV-EVO','Revolution EVO','CT scanner, 128-slice','10050007',2,'ACTIVE','2024-05-22'),
(1008,1,3,'VOL-E10','Voluson E10','OB/GYN ultrasound','10050008',2,'ACTIVE','2023-09-14'),
(1009,1,9,'ENGSTROM','Engstrom Carestation','Anesthesia system w/ ventilator','10050009',2,'ACTIVE','2023-04-18'),
(1010,1,9,'AESTIVA-5','Aestiva 5','Anesthesia machine, legacy','10050010',2,'DISCONTINUED','2023-01-05'),
-- Philips devices (MFR_ID=2)
(1011,2,1,'MX800','IntelliVue MX800','Critical care bedside monitor','10050011',2,'ACTIVE','2024-02-28'),
(1012,2,2,'X3','IntelliVue X3','Transport monitor, wireless','10050012',2,'ACTIVE','2023-07-12'),
(1013,2,3,'EPIQ-ELITE','EPIQ Elite','Premium ultrasound, 3D/4D','10050013',2,'ACTIVE','2024-04-01'),
(1014,2,4,'CX50','CX50 CompactXtreme','Compact POCUS','10050014',2,'ACTIVE','2023-12-15'),
(1015,2,5,'INCISIVE-7100','Incisive CT','CT scanner, 128-slice, dual-energy',NULL,2,'ACTIVE','2023-10-20'),
(1016,2,10,'V680','Respironics V680','ICU ventilator','10050016',2,'ACTIVE','2024-06-11'),
(1017,2,7,'DD-C90','DigitalDiagnost C90','Ceiling DR system','10050017',2,'ACTIVE','2023-03-25'),
(1018,2,28,'AZURION-7','Azurion 7 C20','Interventional X-ray','10050018',2,'ACTIVE','2024-01-30'),
(1019,2,4,'LUMIFY','Lumify','Handheld ultrasound','10050019',2,'ACTIVE','2023-09-08'),
(1020,2,15,'MRX','HeartStart MRx','Defib/monitor w/ pacing','10050020',3,'ACTIVE','2023-05-15'),
-- Siemens devices (MFR_ID=3)
(1021,3,5,'FORCE','SOMATOM Force','CT, dual source, 384-slice equiv','10050021',2,'ACTIVE','2024-03-01'),
(1022,3,6,'VIDA-3T','MAGNETOM Vida','MRI, 3 Tesla','10050022',2,'ACTIVE','2023-06-15'),
(1023,3,3,'SEQUOIA','ACUSON Sequoia','Premium ultrasound','10050023',2,'ACTIVE','2024-04-20'),
(1024,3,28,'ARTIS-ICONO','Artis icono','Angiography system','10050024',2,'ACTIVE','2023-12-10'),
(1025,3,7,'YSIO-MAX','Ysio Max','Ceiling DR, wireless detector','10050025',2,'ACTIVE','2023-11-28'),
(1026,3,5,'GO-TOP','SOMATOM go.Top','CT, 128-slice, tablet-op','10050026',2,'ACTIVE','2023-08-30'),
(1027,3,3,'SC2000','SC2000 PRIME','Cardiac ultrasound','10050027',2,'ACTIVE','2024-02-14'),
(1028,3,7,'IMPACT-C','Multix Impact C','Floor DR system','10050028',2,'ACTIVE','2023-04-05'),
(1029,3,7,'ELARA-MAX','Mobilett Elara Max','Mobile DR','10050029',2,'ACTIVE','2023-05-18'),
(1030,3,29,'ATELLICA','Atellica Solution','Chemistry/immuno analyzer','10050030',1,'ACTIVE','2024-01-05'),
-- Medtronic devices (MFR_ID=4)
(1031,4,10,'PB980','Puritan Bennett 980','ICU ventilator','10050031',2,'ACTIVE','2023-11-15'),
(1032,4,17,'PM1000N','Nellcor PM1000N','Pulse oximeter','10050032',2,'ACTIVE','2023-03-22'),
(1033,4,19,'FT10','Valleylab FT10','Electrosurgical generator','10050033',2,'ACTIVE','2023-07-01'),
(1034,4,10,'PB840','Puritan Bennett 840','ICU ventilator, legacy','10050034',2,'LEGACY','2023-09-10'),
(1035,4,17,'BIS-VISTA','BIS VISTA','Depth of anesthesia monitor',NULL,2,'ACTIVE','2023-08-16'),
(1036,4,23,'S8','StealthStation S8','Surgical navigation','10050036',2,'ACTIVE','2024-05-01'),
(1037,4,14,'EPUMP','Kangaroo ePump','Enteral feeding pump','10050037',2,'ACTIVE','2023-02-20'),
(1038,4,17,'CS35','Capnostream 35','Capnography + SpO2 monitor','10050038',2,'ACTIVE','2023-10-05'),
-- Stryker devices (MFR_ID=5)
(1039,5,20,'SYS8-SAG','System 8 Sagittal','Powered saw, large bone','10050039',1,'ACTIVE','2024-01-18'),
(1040,5,21,'1288HD','1288 HD Camera','Endo camera, HD 3-chip','10050040',2,'ACTIVE','2023-04-12'),
(1041,5,34,'INTOUCH','InTouch ICU','Remote presence robot',NULL,2,'ACTIVE','2023-07-30'),
(1042,5,20,'PL-6500','Power-LOAD','Powered cot loader','10050042',1,'ACTIVE','2023-11-25'),
(1043,5,40,'NEPTUNE3','Neptune 3','Surgical waste system','10050043',1,'ACTIVE','2024-03-08'),
-- Baxter devices (MFR_ID=6)
(1044,6,13,'SPECTRUM-IQ','SIGMA Spectrum IQ','LVP infusion pump','10050044',2,'ACTIVE','2023-06-28'),
(1045,6,13,'CXE','Colleague CXE','LVP infusion pump, legacy',NULL,2,'LEGACY','2023-11-20'),
(1046,6,29,'PRISMAX','PrisMax','CRRT system','10050046',2,'ACTIVE','2024-02-05'),
(1047,6,29,'CLARIA','HomeChoice Claria','PD cycler','10050047',2,'ACTIVE','2023-08-18'),
(1048,6,13,'6301','Flo-Gard 6301','LVP pump, legacy','10050048',2,'DISCONTINUED','2023-06-01'),
-- Draeger devices (MFR_ID=7)
(1049,7,9,'A500','Perseus A500','Anesthesia workstation','10050049',2,'ACTIVE','2023-09-22'),
(1050,7,10,'V800','Evita V800','ICU ventilator','10050050',2,'ACTIVE','2024-04-15'),
(1051,7,11,'VN800','Babylog VN800','Neonatal ventilator','10050051',2,'ACTIVE','2023-01-10'),
(1052,7,2,'M540','Infinity M540','Transport monitor','10050052',2,'ACTIVE','2023-10-28'),
-- BD devices (MFR_ID=8)
(1053,8,13,'ALARIS-8015','Alaris System','Modular infusion pump','10050053',2,'ACTIVE','2024-05-10'),
(1054,8,33,'PYXIS-ES','Pyxis MedStation ES','Med dispensing cabinet','10050054',2,'ACTIVE','2023-12-01'),
(1055,8,10,'AVEA','AVEA Ventilator','ICU ventilator, legacy','10050055',2,'LEGACY','2023-07-15'),
(1056,8,29,'VERITOR','Veritor Plus','Rapid diagnostic analyzer','10050056',1,'ACTIVE','2023-03-14'),
-- Hill-Rom devices (MFR_ID=9)
(1057,9,25,'CENTRELLA','Centrella Smart+ Bed','Hospital bed, smart','10050057',2,'ACTIVE','2023-10-12'),
(1058,9,25,'PROGRESSA','Progressa Pulmonary','ICU bed, pulmonary therapy','10050058',2,'ACTIVE','2024-01-25'),
(1059,9,18,'VSM6000','Connex VSM 6000','Vital signs monitor','10050059',2,'ACTIVE','2023-05-30'),
(1060,9,37,'RV700','RetinaVue 700','Fundus camera','10050060',2,'ACTIVE','2023-12-08'),
-- Canon/Toshiba devices (MFR_ID=10)
(1061,10,5,'ONE-PRISM','Aquilion ONE PRISM','CT, 320-row','10050061',2,'ACTIVE','2024-06-01'),
(1062,10,5,'PRIME-SP','Aquilion Prime SP','CT, 160-slice','10050062',2,'LEGACY','2023-02-14'),
(1063,10,3,'I800','Aplio i800','Premium ultrasound','10050063',2,'ACTIVE','2023-07-20'),
(1064,10,3,'XARIO-200','Xario 200','Mid-range ultrasound','10050064',2,'LEGACY','2023-04-10'),
-- ZOLL devices (MFR_ID=11)
(1065,11,15,'R-SERIES','R Series Plus','Defib/monitor','10050065',3,'ACTIVE','2023-08-22'),
(1066,11,30,'TGXP','Thermogard XP','Temp management','10050066',2,'ACTIVE','2024-03-18'),
(1067,11,16,'AED3','AED 3','AED, public access','10050067',3,'ACTIVE','2023-01-28'),
-- Masimo devices (MFR_ID=12)
(1068,12,17,'ROOT','Root','Monitoring platform','10050068',2,'ACTIVE','2024-04-05'),
(1069,12,17,'RAD7','Radical-7','Pulse ox, rainbow SET','10050069',2,'ACTIVE','2023-06-10'),
(1070,12,17,'RAD97','Rad-97','Pulse ox, tabletop','10050070',2,'ACTIVE','2023-11-30'),
-- Mindray devices (MFR_ID=13)
(1071,13,1,'N22','BeneVision N22','Bedside monitor','10050071',2,'ACTIVE','2024-02-20'),
(1072,13,2,'N1','BeneVision N1','Transport monitor','10050072',2,'ACTIVE','2023-09-15'),
(1073,13,3,'RESONA-I9','Resona I9','Premium ultrasound','10050073',2,'ACTIVE','2024-05-28'),
(1074,13,10,'SV300','SV300','ICU ventilator','10050074',2,'ACTIVE','2023-04-22'),
-- Getinge/Maquet devices (MFR_ID=14)
(1075,14,10,'SERVO-U','Servo-u','ICU ventilator, NAVA','10050075',2,'ACTIVE','2024-01-15'),
(1076,14,9,'FLOW-I','FLOW-i','Anesthesia system','10050076',2,'ACTIVE','2023-03-08'),
(1077,14,34,'TEGRIS','Tegris','OR integration','10050077',1,'ACTIVE','2023-08-14'),
-- Nihon Kohden devices (MFR_ID=15)
(1078,15,1,'PVM4763','Vismo PVM-4763','Bedside monitor','10050078',2,'ACTIVE','2024-06-05'),
(1079,15,16,'AED3100','NK AED-3100','AED, biphasic','10050079',3,'ACTIVE','2023-02-18'),
(1080,15,38,'WEE1000','WEE-1000','EEG system','10050080',2,'ACTIVE','2023-10-30'),
-- Smith+Nephew devices (MFR_ID=16)
(1081,16,24,'CORI','CORI Surgical','Robotic surgical platform','10050081',2,'ACTIVE','2024-04-12'),
(1082,16,20,'POWER-II','DYONICS POWER II','Arthroscopic shaver','10050082',1,'ACTIVE','2023-01-05'),
(1083,16,21,'1000XL','1000XL Camera','Endo camera, 4K','10050083',2,'ACTIVE','2023-07-18'),
-- Olympus devices (MFR_ID=17)
(1084,17,22,'CV1500','EVIS X1','Video processor, AI','10050084',2,'ACTIVE','2024-02-28'),
(1085,17,22,'Q190V','TJF-Q190V','Duodenoscope','10050085',2,'ACTIVE','2023-05-14'),
(1086,17,22,'HQ190','GIF-HQ190','Gastroscope, HD','10050086',2,'ACTIVE','2023-11-08'),
-- Hamilton devices (MFR_ID=18)
(1087,18,10,'C6','Hamilton C6','ICU ventilator, INTELLiVENT','10050087',2,'ACTIVE','2024-05-15'),
(1088,18,12,'T1','Hamilton T1','Transport/ICU ventilator','10050088',2,'ACTIVE','2023-06-25'),
-- Misc devices
(1089,26,18,'VSM4400','Spot 4400','Vital signs, spot-check','10050089',2,'ACTIVE','2023-09-20'),
(1090,19,1,'XPREZZON','Xprezzon','Bedside monitor','10050090',2,'ACTIVE','2023-04-05'),
(1091,20,26,'V160H','Century V-160H','Steam sterilizer','10050091',2,'ACTIVE','2023-08-01'),
(1092,20,27,'HARMONY-AIR','Harmony aIR','Surgical light, LED','10050092',1,'ACTIVE','2024-03-22'),
(1093,7,31,'C2000','Isolette C2000','Infant incubator','10050093',2,'ACTIVE','2023-02-10'),
(1094,21,35,'ALGO5','ALGO 5','Hearing screener','10050094',2,'ACTIVE','2023-11-15'),
(1095,22,36,'DIMENSIONS','Selenia Dimensions','3D mammography','10050095',2,'ACTIVE','2023-07-08'),
(1096,23,7,'D-EVO-III','FDR D-EVO III','Wireless DR detector','10050096',2,'ACTIVE','2024-01-12'),
(1097,23,8,'CAPSULA-XLII','FCR Capsula XLII','CR reader, legacy','10050097',2,'LEGACY','2023-05-30'),
(1098,24,39,'EZ-IO','Arrow EZ-IO','IO vascular access','10050098',2,'ACTIVE','2023-09-28'),
(1099,25,10,'AVEA-CVS','AVEA CVS','ICU ventilator','10050099',2,'ACTIVE','2023-06-14'),
(1100,25,32,'MS-PFT','MasterScreen PFT','Pulmonary function test','10050100',2,'ACTIVE','2023-08-22');

-- -----------------------------------------------------------------------------
-- PM_SCHEDULE  (maintenance templates by device family)
-- Defines how often each device family needs preventative maintenance.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PM_SCHEDULE (
    PM_ID           NUMBER,
    FAMILY_ID       NUMBER,       -- FK to DEVICE_FAMILY
    PM_TYPE         STRING,       -- FULL_PM / INTERIM_PM / CALIBRATION / SAFETY_CHECK
    INTERVAL_MONTHS NUMBER,       -- how often
    EST_LABOR_HOURS NUMBER(5,1),  -- estimated tech time per PM
    DESCRIPTION     STRING
);

INSERT INTO PM_SCHEDULE VALUES
(1,1,'FULL_PM',12,3.0,'Annual full PM - bedside monitors: electrical safety, sensor cal, battery test, SW update'),
(2,1,'INTERIM_PM',6,1.0,'Semi-annual interim - bedside monitors: visual inspection, alarm test, cable check'),
(3,2,'FULL_PM',12,2.0,'Annual full PM - transport monitors: battery load test, sensor cal, drop test'),
(4,3,'FULL_PM',12,6.0,'Annual full PM - diagnostic ultrasound: transducer test, image quality, DICOM verify'),
(5,3,'CALIBRATION',6,2.0,'Semi-annual cal - ultrasound: phantom scan, measurement accuracy'),
(6,4,'FULL_PM',12,2.5,'Annual full PM - POCUS: transducer check, battery, SW update'),
(7,5,'FULL_PM',12,16.0,'Annual full PM - CT scanner: tube output, dose cal, image quality, mechanical inspect'),
(8,5,'CALIBRATION',3,4.0,'Quarterly cal - CT: air cal, water phantom, HU accuracy'),
(9,6,'FULL_PM',12,24.0,'Annual full PM - MRI: coil test, gradient check, shim, phantom scan, quench system'),
(10,7,'FULL_PM',12,4.0,'Annual full PM - DR: generator output, detector cal, AEC test, collimation'),
(11,8,'FULL_PM',12,3.0,'Annual full PM - CR: plate reader, erasure, laser, image quality'),
(12,9,'FULL_PM',12,8.0,'Annual full PM - anesthesia: vaporizer cal, leak test, ventilator check, safety systems'),
(13,9,'SAFETY_CHECK',6,2.0,'Semi-annual safety - anesthesia: O2 sensor, CO2 absorber, pressure test'),
(14,10,'FULL_PM',12,6.0,'Annual full PM - ICU ventilator: flow sensor cal, pressure test, battery, O2 cell'),
(15,10,'INTERIM_PM',6,2.0,'Semi-annual interim - ventilator: filter change, alarm test, circuit check'),
(16,11,'FULL_PM',12,5.0,'Annual full PM - neonatal ventilator: flow accuracy, pressure cal, humidifier, safety'),
(17,12,'FULL_PM',12,4.0,'Annual full PM - transport ventilator: battery, gas supply, alarm check'),
(18,13,'FULL_PM',12,2.0,'Annual full PM - infusion pump: flow accuracy, occlusion, air-in-line, drug library'),
(19,13,'SAFETY_CHECK',6,0.5,'Semi-annual safety - pump: alarm function, battery, visual inspect'),
(20,14,'FULL_PM',12,1.5,'Annual full PM - enteral pump: flow test, alarm, rotor inspection'),
(21,15,'FULL_PM',12,4.0,'Annual full PM - defibrillator: energy output, ECG cal, battery, pacing test'),
(22,16,'FULL_PM',12,1.0,'Annual full PM - AED: self-test verify, pad expiry, battery capacity'),
(23,17,'FULL_PM',12,1.0,'Annual full PM - pulse ox: SpO2 accuracy, alarm test, sensor check'),
(24,18,'FULL_PM',12,1.5,'Annual full PM - vital signs: NIBP accuracy, temp cal, SpO2 check'),
(25,19,'FULL_PM',12,3.0,'Annual full PM - ESU: power output test, REM alarm, cable inspection'),
(26,20,'FULL_PM',12,2.0,'Annual full PM - powered instrument: speed test, torque, seal integrity'),
(27,21,'FULL_PM',12,3.0,'Annual full PM - endo camera: color balance, focus, light output, white balance'),
(28,22,'FULL_PM',6,2.0,'Semi-annual full PM - endoscope: leak test, angulation, image quality, channel brush'),
(29,23,'FULL_PM',12,8.0,'Annual full PM - surgical nav: tracking accuracy, registration, SW calibration'),
(30,24,'FULL_PM',12,12.0,'Annual full PM - surgical robot: joint cal, force sensing, instrument check'),
(31,25,'FULL_PM',12,3.0,'Annual full PM - hospital bed: electrical, hydraulic, scale cal, siderail, brakes'),
(32,26,'FULL_PM',12,8.0,'Annual full PM - sterilizer: chamber leak, temp/pressure verify, BI test'),
(33,27,'FULL_PM',12,1.5,'Annual full PM - surgical light: intensity, color temp, focus, arm balance'),
(34,28,'FULL_PM',12,16.0,'Annual full PM - interventional X-ray: generator, detector, mechanical, dose cal'),
(35,29,'FULL_PM',12,6.0,'Annual full PM - lab analyzer: reagent line, optics, calibrator, QC run'),
(36,30,'FULL_PM',12,3.0,'Annual full PM - temp management: temperature accuracy, flow test, alarm check'),
(37,31,'FULL_PM',12,4.0,'Annual full PM - incubator: temp/humidity accuracy, alarm, air circulation, skin probe'),
(38,32,'FULL_PM',12,4.0,'Annual full PM - PFT: volume cal, flow sensor, gas analyzer, leak test'),
(39,33,'FULL_PM',12,4.0,'Annual full PM - med dispensing: lock mechanism, biometric, inventory count, SW update'),
(40,34,'FULL_PM',12,6.0,'Annual full PM - OR integration: video routing, camera interface, recording, network'),
(41,35,'FULL_PM',12,1.5,'Annual full PM - hearing screener: transducer cal, probe test, SW update'),
(42,36,'FULL_PM',12,12.0,'Annual full PM - mammography: AEC, phantom image, compression force, dose'),
(43,37,'FULL_PM',12,2.0,'Annual full PM - fundus camera: optics alignment, flash test, image quality'),
(44,38,'FULL_PM',12,4.0,'Annual full PM - EEG: channel cal, impedance check, montage verify, artifact test'),
(45,39,'FULL_PM',12,0.5,'Annual full PM - IO access: device function test, battery, needle check'),
(46,40,'FULL_PM',12,2.0,'Annual full PM - waste management: suction test, canister seal, filter, decontamination');

-- -----------------------------------------------------------------------------
-- SERVICE_COST_ESTIMATE  (annual cost per device catalog entry)
-- This is what drives the quote for a new site.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SERVICE_COST_ESTIMATE (
    COST_ID         NUMBER,
    CATALOG_ID      NUMBER,       -- FK to DEVICE_CATALOG
    ANNUAL_PARTS_COST   NUMBER(10,2),  -- estimated annual parts spend
    ANNUAL_LABOR_COST   NUMBER(10,2),  -- estimated annual labor cost
    ANNUAL_PM_COST      NUMBER(10,2),  -- PM-specific cost (subset of labor+parts)
    ANNUAL_TOTAL_COST   NUMBER(10,2),  -- total annual service cost
    RISK_TIER       STRING,       -- HIGH / MEDIUM / LOW (based on FDA class + criticality)
    COST_CONFIDENCE STRING,       -- HIGH / MEDIUM / LOW (how reliable the estimate is)
    EFFECTIVE_DATE  DATE
);

INSERT INTO SERVICE_COST_ESTIMATE VALUES
-- GE devices
(1,1001,2400.00,3600.00,1800.00,6000.00,'MEDIUM','HIGH','2024-01-01'),
(2,1002,3200.00,4800.00,2400.00,8000.00,'HIGH','HIGH','2024-01-01'),
(3,1003,4500.00,7200.00,3600.00,11700.00,'MEDIUM','MEDIUM','2024-01-01'),
(4,1004,3000.00,4800.00,2400.00,7800.00,'MEDIUM','HIGH','2024-01-01'),
(5,1005,1200.00,2400.00,1200.00,3600.00,'LOW','HIGH','2024-01-01'),
(6,1006,4000.00,6000.00,3000.00,10000.00,'MEDIUM','MEDIUM','2024-01-01'),
(7,1007,18000.00,19200.00,9600.00,37200.00,'MEDIUM','HIGH','2024-01-01'),
(8,1008,3800.00,6000.00,3000.00,9800.00,'MEDIUM','MEDIUM','2024-01-01'),
(9,1009,5000.00,9600.00,4800.00,14600.00,'HIGH','HIGH','2024-01-01'),
(10,1010,6500.00,9600.00,4800.00,16100.00,'HIGH','LOW','2024-01-01'),
-- Philips devices
(11,1011,2800.00,3600.00,1800.00,6400.00,'HIGH','HIGH','2024-01-01'),
(12,1012,1800.00,2400.00,1200.00,4200.00,'MEDIUM','HIGH','2024-01-01'),
(13,1013,5000.00,7200.00,3600.00,12200.00,'MEDIUM','HIGH','2024-01-01'),
(14,1014,2000.00,3000.00,1500.00,5000.00,'LOW','HIGH','2024-01-01'),
(15,1015,16000.00,19200.00,9600.00,35200.00,'MEDIUM','MEDIUM','2024-01-01'),
(16,1016,3500.00,7200.00,3600.00,10700.00,'HIGH','HIGH','2024-01-01'),
(17,1017,3500.00,4800.00,2400.00,8300.00,'MEDIUM','HIGH','2024-01-01'),
(18,1018,22000.00,19200.00,9600.00,41200.00,'MEDIUM','HIGH','2024-01-01'),
(19,1019,800.00,1200.00,600.00,2000.00,'LOW','HIGH','2024-01-01'),
(20,1020,2500.00,4800.00,2400.00,7300.00,'HIGH','HIGH','2024-01-01'),
-- Siemens devices
(21,1021,25000.00,19200.00,9600.00,44200.00,'MEDIUM','HIGH','2024-01-01'),
(22,1022,20000.00,28800.00,14400.00,48800.00,'MEDIUM','MEDIUM','2024-01-01'),
(23,1023,4200.00,6000.00,3000.00,10200.00,'MEDIUM','HIGH','2024-01-01'),
(24,1024,24000.00,19200.00,9600.00,43200.00,'MEDIUM','HIGH','2024-01-01'),
(25,1025,3200.00,4800.00,2400.00,8000.00,'MEDIUM','HIGH','2024-01-01'),
(26,1026,14000.00,19200.00,9600.00,33200.00,'MEDIUM','HIGH','2024-01-01'),
(27,1027,3800.00,6000.00,3000.00,9800.00,'MEDIUM','MEDIUM','2024-01-01'),
(28,1028,2800.00,4800.00,2400.00,7600.00,'MEDIUM','HIGH','2024-01-01'),
(29,1029,2500.00,4800.00,2400.00,7300.00,'MEDIUM','HIGH','2024-01-01'),
(30,1030,8000.00,7200.00,3600.00,15200.00,'LOW','MEDIUM','2024-01-01'),
-- Medtronic devices
(31,1031,4000.00,7200.00,3600.00,11200.00,'HIGH','HIGH','2024-01-01'),
(32,1032,400.00,1200.00,600.00,1600.00,'MEDIUM','HIGH','2024-01-01'),
(33,1033,1800.00,3600.00,1800.00,5400.00,'MEDIUM','HIGH','2024-01-01'),
(34,1034,5500.00,7200.00,3600.00,12700.00,'HIGH','LOW','2024-01-01'),
(35,1035,1200.00,2400.00,1200.00,3600.00,'MEDIUM','MEDIUM','2024-01-01'),
(36,1036,12000.00,9600.00,4800.00,21600.00,'HIGH','HIGH','2024-01-01'),
(37,1037,600.00,1800.00,900.00,2400.00,'LOW','HIGH','2024-01-01'),
(38,1038,800.00,1200.00,600.00,2000.00,'MEDIUM','HIGH','2024-01-01'),
-- Stryker devices
(39,1039,1500.00,2400.00,1200.00,3900.00,'LOW','HIGH','2024-01-01'),
(40,1040,2000.00,3600.00,1800.00,5600.00,'MEDIUM','HIGH','2024-01-01'),
(41,1041,8000.00,6000.00,3000.00,14000.00,'MEDIUM','MEDIUM','2024-01-01'),
(42,1042,1200.00,2400.00,1200.00,3600.00,'LOW','HIGH','2024-01-01'),
(43,1043,800.00,2400.00,1200.00,3200.00,'LOW','HIGH','2024-01-01'),
-- Baxter devices
(44,1044,1500.00,2400.00,1200.00,3900.00,'MEDIUM','HIGH','2024-01-01'),
(45,1045,2200.00,2400.00,1200.00,4600.00,'MEDIUM','LOW','2024-01-01'),
(46,1046,6000.00,7200.00,3600.00,13200.00,'HIGH','HIGH','2024-01-01'),
(47,1047,3000.00,3600.00,1800.00,6600.00,'MEDIUM','MEDIUM','2024-01-01'),
(48,1048,1800.00,2400.00,1200.00,4200.00,'MEDIUM','LOW','2024-01-01'),
-- Draeger devices
(49,1049,5500.00,9600.00,4800.00,15100.00,'HIGH','HIGH','2024-01-01'),
(50,1050,4000.00,7200.00,3600.00,11200.00,'HIGH','HIGH','2024-01-01'),
(51,1051,3500.00,6000.00,3000.00,9500.00,'HIGH','HIGH','2024-01-01'),
(52,1052,1600.00,2400.00,1200.00,4000.00,'MEDIUM','HIGH','2024-01-01'),
-- BD devices
(53,1053,1800.00,2400.00,1200.00,4200.00,'HIGH','HIGH','2024-01-01'),
(54,1054,4000.00,4800.00,2400.00,8800.00,'MEDIUM','HIGH','2024-01-01'),
(55,1055,4500.00,7200.00,3600.00,11700.00,'HIGH','LOW','2024-01-01'),
(56,1056,300.00,1200.00,600.00,1500.00,'LOW','HIGH','2024-01-01'),
-- Hill-Rom devices
(57,1057,1500.00,3600.00,1800.00,5100.00,'LOW','HIGH','2024-01-01'),
(58,1058,2500.00,3600.00,1800.00,6100.00,'MEDIUM','HIGH','2024-01-01'),
(59,1059,600.00,1800.00,900.00,2400.00,'LOW','HIGH','2024-01-01'),
(60,1060,1200.00,2400.00,1200.00,3600.00,'LOW','MEDIUM','2024-01-01'),
-- Canon/Toshiba devices
(61,1061,20000.00,19200.00,9600.00,39200.00,'MEDIUM','HIGH','2024-01-01'),
(62,1062,15000.00,19200.00,9600.00,34200.00,'MEDIUM','LOW','2024-01-01'),
(63,1063,4500.00,7200.00,3600.00,11700.00,'MEDIUM','HIGH','2024-01-01'),
(64,1064,3000.00,6000.00,3000.00,9000.00,'MEDIUM','LOW','2024-01-01'),
-- ZOLL devices
(65,1065,2200.00,4800.00,2400.00,7000.00,'HIGH','HIGH','2024-01-01'),
(66,1066,5000.00,3600.00,1800.00,8600.00,'MEDIUM','MEDIUM','2024-01-01'),
(67,1067,200.00,1200.00,600.00,1400.00,'LOW','HIGH','2024-01-01'),
-- Masimo devices
(68,1068,600.00,1200.00,600.00,1800.00,'MEDIUM','HIGH','2024-01-01'),
(69,1069,500.00,1200.00,600.00,1700.00,'MEDIUM','HIGH','2024-01-01'),
(70,1070,400.00,1200.00,600.00,1600.00,'LOW','HIGH','2024-01-01'),
-- Mindray devices
(71,1071,2000.00,3600.00,1800.00,5600.00,'MEDIUM','MEDIUM','2024-01-01'),
(72,1072,1400.00,2400.00,1200.00,3800.00,'MEDIUM','MEDIUM','2024-01-01'),
(73,1073,3800.00,6000.00,3000.00,9800.00,'MEDIUM','MEDIUM','2024-01-01'),
(74,1074,3200.00,7200.00,3600.00,10400.00,'HIGH','MEDIUM','2024-01-01'),
-- Getinge/Maquet devices
(75,1075,3800.00,7200.00,3600.00,11000.00,'HIGH','HIGH','2024-01-01'),
(76,1076,5000.00,9600.00,4800.00,14600.00,'HIGH','HIGH','2024-01-01'),
(77,1077,3000.00,7200.00,3600.00,10200.00,'LOW','MEDIUM','2024-01-01'),
-- Nihon Kohden devices
(78,1078,2200.00,3600.00,1800.00,5800.00,'MEDIUM','MEDIUM','2024-01-01'),
(79,1079,200.00,1200.00,600.00,1400.00,'LOW','MEDIUM','2024-01-01'),
(80,1080,2000.00,4800.00,2400.00,6800.00,'MEDIUM','MEDIUM','2024-01-01'),
-- Smith+Nephew devices
(81,1081,8000.00,14400.00,7200.00,22400.00,'MEDIUM','MEDIUM','2024-01-01'),
(82,1082,1000.00,2400.00,1200.00,3400.00,'LOW','HIGH','2024-01-01'),
(83,1083,1800.00,3600.00,1800.00,5400.00,'MEDIUM','HIGH','2024-01-01'),
-- Olympus devices
(84,1084,3000.00,3600.00,1800.00,6600.00,'MEDIUM','HIGH','2024-01-01'),
(85,1085,4000.00,2400.00,1200.00,6400.00,'MEDIUM','HIGH','2024-01-01'),
(86,1086,3500.00,2400.00,1200.00,5900.00,'MEDIUM','HIGH','2024-01-01'),
-- Hamilton devices
(87,1087,3500.00,7200.00,3600.00,10700.00,'HIGH','HIGH','2024-01-01'),
(88,1088,2800.00,4800.00,2400.00,7600.00,'HIGH','HIGH','2024-01-01'),
-- Misc devices
(89,1089,500.00,1800.00,900.00,2300.00,'LOW','HIGH','2024-01-01'),
(90,1090,1800.00,3600.00,1800.00,5400.00,'MEDIUM','MEDIUM','2024-01-01'),
(91,1091,4000.00,9600.00,4800.00,13600.00,'MEDIUM','HIGH','2024-01-01'),
(92,1092,400.00,1800.00,900.00,2200.00,'LOW','HIGH','2024-01-01'),
(93,1093,2500.00,4800.00,2400.00,7300.00,'HIGH','HIGH','2024-01-01'),
(94,1094,600.00,1800.00,900.00,2400.00,'LOW','MEDIUM','2024-01-01'),
(95,1095,10000.00,14400.00,7200.00,24400.00,'MEDIUM','HIGH','2024-01-01'),
(96,1096,2000.00,4800.00,2400.00,6800.00,'MEDIUM','HIGH','2024-01-01'),
(97,1097,1500.00,3600.00,1800.00,5100.00,'MEDIUM','LOW','2024-01-01'),
(98,1098,200.00,600.00,300.00,800.00,'LOW','HIGH','2024-01-01'),
(99,1099,4000.00,7200.00,3600.00,11200.00,'HIGH','MEDIUM','2024-01-01'),
(100,1100,2500.00,4800.00,2400.00,7300.00,'MEDIUM','MEDIUM','2024-01-01');
