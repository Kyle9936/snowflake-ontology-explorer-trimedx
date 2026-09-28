/* =============================================================================
   SYSTEM 1 of 3:  FDA_DEVICES  (the FDA GUDID-style device registry)
   -----------------------------------------------------------------------------
   Demo purpose: messy source data for an MMD ontology-alignment demo.

   This system's vocabulary:
     - A device is a "DEVICE_RECORD" (identified by GUDID / primary DI)
     - A manufacturer is "COMPANY_NAME" (free-text, no canonical ID)
     - A model is "VERSION_MODEL_NUMBER" (may differ from commercial name)
     - A category is "PRODUCT_CODE" + "MEDICAL_SPECIALTY_CODE"
     - Risk class is "DEVICE_CLASS" (I, II, III)

   Intentional messiness in this file:
     1. COMPANY_NAME is free-text with inconsistent formatting:
        "GE Healthcare" vs "General Electric Co" vs "GE Medical Systems"
     2. VERSION_MODEL_NUMBER sometimes includes revision suffixes (v2, Rev B)
        that the other systems don't carry.
     3. DEVICE_DESCRIPTION is verbose and clinical, while other systems use
        abbreviated commercial names.
     4. Some records have NULL CATALOG_NUMBER (the commercial part number).
     5. PRODUCT_CODE is a 3-letter FDA code that doesn't exist in other systems.

   Cross-system linkage keys (so the ontology CAN traverse later):
     - GUDID_DI           -> aligns to TRIMEDX_MMD.DEVICE_CATALOG.FDA_DI (direct)
     - COMPANY_NAME       -> fuzzy match to TRIMEDX_MMD.MANUFACTURER.MFR_NAME
                             and SITE_INVENTORY.RAW.EQUIPMENT_LIST.MANUFACTURER
     - VERSION_MODEL_NUMBER -> fuzzy match to other systems' model fields
     - CATALOG_NUMBER     -> sometimes matches TRIMEDX_MMD.DEVICE_CATALOG.PART_NUMBER
   =============================================================================*/

CREATE DATABASE IF NOT EXISTS FDA_DEVICES;
CREATE SCHEMA   IF NOT EXISTS FDA_DEVICES.GUDID;
USE SCHEMA FDA_DEVICES.GUDID;

-- -----------------------------------------------------------------------------
-- DEVICE_RECORD  (one row per unique device identifier from GUDID)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE DEVICE_RECORD (
    GUDID_DI                STRING,       -- Global Unique Device Identifier
    COMPANY_NAME            STRING,       -- manufacturer (free-text, inconsistent)
    BRAND_NAME              STRING,       -- commercial brand name
    VERSION_MODEL_NUMBER    STRING,       -- model number (may include revision)
    CATALOG_NUMBER          STRING,       -- commercial catalog/part number (nullable)
    DEVICE_DESCRIPTION      STRING,       -- verbose FDA description
    DEVICE_CLASS            NUMBER,       -- FDA risk class: 1, 2, or 3
    PRODUCT_CODE            STRING,       -- 3-letter FDA product code
    MEDICAL_SPECIALTY_CODE  STRING,       -- 2-letter FDA specialty
    DEVICE_STATUS           STRING,       -- In Commercial Distribution / Not in Commercial Distribution
    PUBLISH_DATE            DATE
);

INSERT INTO DEVICE_RECORD VALUES
-- ===== GE HEALTHCARE (appears as 3 different company names) =====
('10050001','GE Healthcare','CARESCAPE Monitor B650','B650 v2','2089526-002','Patient monitor, bedside, high-acuity, multiparameter with integrated display',2,'MEC','AN','In Commercial Distribution','2023-03-15'),
('10050002','GE Healthcare','CARESCAPE Monitor B850','B850','2089526-003','Patient monitor, bedside, critical care, multiparameter hemodynamic',2,'MEC','AN','In Commercial Distribution','2023-03-15'),
('10050003','General Electric Co','Vivid E95','?"Vivid E95 Rev C','H45561KS','Diagnostic ultrasound system, cardiac, with advanced quantification',2,'IYO','CV','In Commercial Distribution','2022-11-01'),
('10050004','GE Medical Systems','Optima XR240amx','XR240amx','5831200-2','Mobile digital radiography system, general purpose',2,'QKQ','RA','In Commercial Distribution','2021-06-20'),
('10050005','GE Healthcare','Venue Go','Venue Go R3','H45571QE','Point-of-care ultrasound system, portable, with AI-assisted tools',2,'IYO','CV','In Commercial Distribution','2023-01-10'),
('10050006','General Electric Co','LOGIQ E10s','E10s v2','H45581LG','Diagnostic ultrasound system, general imaging, shared service',2,'IYO','RA','In Commercial Distribution','2022-08-05'),
('10050007','GE Healthcare','Revolution EVO','Revolution EVO Gen 3','5614811-9','Computed tomography system, full body, 128-slice',2,'JAK','RA','In Commercial Distribution','2023-05-22'),
('10050008','GE Medical Systems','Voluson E10','Vol E10 BT20',NULL,'Diagnostic ultrasound system, obstetric and gynecologic',2,'IYO','OB','In Commercial Distribution','2021-09-14'),
('10050009','GE Healthcare','Engstrom Carestation','Engstrom CS','5120200-5','Anesthesia delivery system with integrated ventilator and gas monitoring',2,'BSZ','AN','In Commercial Distribution','2022-04-18'),
('10050010','General Electric Co','Aestiva 5','Aestiva/5 7900','5120100-3','Anesthesia machine, continuous-flow, with electronic vaporizer',2,'BSZ','AN','Not in Commercial Distribution','2019-01-05'),

-- ===== PHILIPS (appears as 3 different company names) =====
('10050011','Philips Medical Systems','IntelliVue MX800','MX800','866040','Patient monitor, critical care, bedside, with touchscreen display',2,'MEC','AN','In Commercial Distribution','2023-02-28'),
('10050012','Koninklijke Philips N.V.','IntelliVue X3','X3 M','989803196521','Transport patient monitor, compact, with wireless connectivity',2,'MEC','AN','In Commercial Distribution','2022-07-12'),
('10050013','Philips Healthcare','EPIQ Elite','EPIQ Elite','989605413561','Premium diagnostic ultrasound system, advanced 3D/4D imaging',2,'IYO','CV','In Commercial Distribution','2023-04-01'),
('10050014','Philips Medical Systems','CX50 CompactXtreme','CX50 xMATRIX','453561711611','Compact diagnostic ultrasound system, point-of-care and shared service',2,'IYO','RA','In Commercial Distribution','2021-12-15'),
('10050015','Koninklijke Philips N.V.','Incisive CT','Incisive CT 7100',NULL,'Computed tomography system, 128-slice, dual-energy capable',2,'JAK','RA','In Commercial Distribution','2022-10-20'),
('10050016','Philips Healthcare','Respironics V680','V680 v3.7','1141685','Critical care ventilator, invasive and noninvasive, with proportional assist',2,'MNR','AN','In Commercial Distribution','2023-06-11'),
('10050017','Philips Medical Systems','DigitalDiagnost C90','DD C90','989000090041','Digital radiography system, ceiling-mounted, dual detector',2,'QKQ','RA','In Commercial Distribution','2022-03-25'),
('10050018','Koninklijke Philips N.V.','Azurion 7 C20','Azurion 7 C20','718090','Interventional X-ray system, floor-mounted, with live 3D guidance',2,'JAA','CV','In Commercial Distribution','2023-01-30'),
('10050019','Philips Healthcare','Lumify','Lumify L12-4','989605384801','Handheld ultrasound transducer, app-based, broadband linear',2,'IYO','RA','In Commercial Distribution','2022-09-08'),
('10050020','Philips Medical Systems','HeartStart MRx','MRx M3535A','M3535A','Monitor/defibrillator, professional, with pacing and SpO2',3,'DRE','CV','In Commercial Distribution','2020-05-15'),

-- ===== SIEMENS HEALTHINEERS (appears as multiple names) =====
('10050021','Siemens Healthineers','SOMATOM Force','Force Dual Source','10849037','Computed tomography system, dual source, 384-slice equivalent',2,'JAK','RA','In Commercial Distribution','2023-03-01'),
('10050022','Siemens Medical Solutions USA','MAGNETOM Vida','Vida 3T','11056340','Magnetic resonance imaging system, 3 Tesla, whole body',2,'LNH','RA','In Commercial Distribution','2022-06-15'),
('10050023','Siemens Healthineers AG','ACUSON Sequoia','Sequoia 2.0','12262671','Diagnostic ultrasound system, premium, with deep abdominal imaging',2,'IYO','RA','In Commercial Distribution','2023-04-20'),
('10050024','Siemens Medical Solutions USA','Artis icono','Artis icono floor','11721590','Angiography system, floor-mounted, biplane-capable',2,'JAA','CV','In Commercial Distribution','2022-12-10'),
('10050025','Siemens Healthineers','Ysio Max','Ysio Max','11048962','Digital radiography system, ceiling-mounted, wireless detector',2,'QKQ','RA','In Commercial Distribution','2021-11-28'),
('10050026','Siemens Healthineers AG','SOMATOM go.Top','go.Top','11435820','Computed tomography system, 128-slice, tablet-operated',2,'JAK','RA','In Commercial Distribution','2022-08-30'),
('10050027','Siemens Medical Solutions USA','SC2000 PRIME','SC2000 v5.0','11392011','Diagnostic ultrasound system, cardiac, with strain and 3D analysis',2,'IYO','CV','In Commercial Distribution','2023-02-14'),
('10050028','Siemens Healthineers','Multix Impact C','Impact C','10765210','Digital radiography system, floor-mounted, with auto-positioning',2,'QKQ','RA','In Commercial Distribution','2021-04-05'),
('10050029','Siemens Healthineers AG','Mobilett Elara Max','Elara Max','11765430','Mobile digital radiography unit, motorized, with 43x43 detector',2,'QKQ','RA','In Commercial Distribution','2022-05-18'),
('10050030','Siemens Medical Solutions USA','Atellica Solution','Atellica','11098764','Automated clinical chemistry and immunoassay analyzer',1,'JJE','CH','In Commercial Distribution','2023-01-05'),

-- ===== MEDTRONIC (appears as multiple names) =====
('10050031','Medtronic, Inc.','Puritan Bennett 980','PB980','10103880-10','Critical care ventilator, invasive, with advanced lung protection',2,'MNR','AN','In Commercial Distribution','2022-11-15'),
('10050032','Covidien LLC','Nellcor PM1000N','PM1000N','PM1000N-1','Pulse oximeter, bedside, with OxiMax technology',2,'DQA','AN','In Commercial Distribution','2021-03-22'),
('10050033','Medtronic plc','Valleylab FT10','FT10','?"FT10-1','Electrosurgical generator, high-frequency, with tissue sensing',2,'GEI','SU','In Commercial Distribution','2022-07-01'),
('10050034','Covidien LLC','Puritan Bennett 840','PB840 v4',NULL,'Critical care ventilator, invasive and noninvasive, with PAV+',2,'MNR','AN','Not in Commercial Distribution','2018-09-10'),
('10050035','Medtronic, Inc.','BIS VISTA','VISTA 186-0210','186-0210-US','Bispectral index monitoring system, depth of anesthesia',2,'GWF','AN','In Commercial Distribution','2021-08-16'),
('10050036','Medtronic plc','StealthStation S8','S8 v2.2','9735838','Surgical navigation system, cranial and spinal, with optical tracking',2,'HQI','NE','In Commercial Distribution','2023-05-01'),
('10050037','Covidien LLC','Kangaroo ePump','ePump ENFit','383400','Enteral feeding pump, portable, with ENFit connector',2,'MDY','GU','In Commercial Distribution','2022-02-20'),
('10050038','Medtronic, Inc.','Capnostream 35','CS35 Rev B','010-3400-00','Respiratory monitor, portable, with capnography and pulse oximetry',2,'CAP','AN','In Commercial Distribution','2022-10-05'),

-- ===== STRYKER (appears as multiple names) =====
('10050039','Stryker Corporation','System 8','System 8 Sagittal','8208-000','Powered surgical instrument, sagittal saw, large bone',1,'HBJ','OR','In Commercial Distribution','2023-01-18'),
('10050040','Howmedica Osteonics Corp','1288 HD Camera','1288 HD 3-chip','0240-031-000','Endoscopic camera system, high definition, 3-chip',2,'GCJ','GU','In Commercial Distribution','2022-04-12'),
('10050041','Stryker Instruments','InTouch ICU','ICU v4','RP-VITA-001','Remote presence robot, intensive care, with pan-tilt camera',2,'QMT','AN','In Commercial Distribution','2021-07-30'),
('10050042','Stryker Corporation','Power-LOAD','PL-6500','6500-101-010','Powered ambulance cot loading system, hydraulic',1,'KZC','SU','In Commercial Distribution','2022-11-25'),
('10050043','Stryker Instruments','Neptune 3','Neptune 3 GS','0703-080-000','Surgical waste management system, continuous suction',1,'FMF','GU','In Commercial Distribution','2023-03-08'),

-- ===== BAXTER (appears as multiple names) =====
('10050044','Baxter International Inc','SIGMA Spectrum','Spectrum IQ v9','35700BAX2','Infusion pump, large volume, with dose error reduction software',2,'FRN','AN','In Commercial Distribution','2022-06-28'),
('10050045','Baxter Healthcare Corporation','Colleague CXE','CXE v6.2',NULL,'Infusion pump, large volume, continuous delivery',2,'FRN','AN','Not in Commercial Distribution','2017-11-20'),
('10050046','Baxter International Inc','PrisMax','PrisMax v3.0','PC10001','Continuous renal replacement therapy system with integrated citrate',2,'FKP','GU','In Commercial Distribution','2023-02-05'),
('10050047','Baxter Healthcare Corporation','HomeChoice Claria','Claria APD','PD10002','Automated peritoneal dialysis cycler, home use',2,'FKP','GU','In Commercial Distribution','2022-08-18'),
('10050048','Baxter International Inc','Flo-Gard 6301','6301','6301-001',NULL,2,'FRN','AN','Not in Commercial Distribution','2015-06-01'),

-- ===== DRAEGER (inconsistent naming) =====
('10050049','Draeger Medical Inc','Perseus A500','A500 SW 3.0','8607900','Anesthesia workstation, closed-circuit, with turbine-driven ventilation',2,'BSZ','AN','In Commercial Distribution','2022-09-22'),
('10050050','Draegerwerk AG','Evita V800','V800 v2.n','8415728','Critical care ventilator, invasive and noninvasive, with autoweaning',2,'MNR','AN','In Commercial Distribution','2023-04-15'),
('10050051','Draeger Medical Inc','Babylog VN800','VN800','8418500','Neonatal ventilator, invasive and noninvasive, with volume guarantee',2,'MNR','AN','In Commercial Distribution','2022-01-10'),
('10050052','Draegerwerk AG','Infinity M540','M540','MS18246','Transport patient monitor, modular, with wireless networking',2,'MEC','AN','In Commercial Distribution','2021-10-28'),

-- ===== BD / BECTON DICKINSON (appears as multiple names) =====
('10050053','Becton Dickinson and Company','Alaris System','Alaris 8015','12345-01','Infusion pump system, modular, with guardrails safety software',2,'FRN','AN','In Commercial Distribution','2023-05-10'),
('10050054','BD','BD Pyxis MedStation ES','MedStation ES v1.8','ES-2000','Automated dispensing cabinet, medication, enterprise with biometric ID',2,'NRC','AN','In Commercial Distribution','2022-12-01'),
('10050055','CareFusion Corporation','AVEA','AVEA v4.6','18900-001','Critical care ventilator, invasive, with comprehensive monitoring',2,'MNR','AN','Not in Commercial Distribution','2019-07-15'),
('10050056','Becton Dickinson and Company','Veritor Plus','Veritor Plus System','256088','Rapid diagnostic test analyzer, immunochromatographic, point-of-care',1,'QKO','MI','In Commercial Distribution','2022-03-14'),

-- ===== HILL-ROM / BAIRD (beds and surfaces) =====
('10050057','Hill-Rom Holdings Inc','Centrella Smart+ Bed','Centrella v2','P3700B','Hospital bed, electric, with integrated scale and position monitoring',2,'FNE','PM','In Commercial Distribution','2022-10-12'),
('10050058','Hillrom','Progressa Pulmonary','Progressa v2','P7500A','ICU bed, pulmonary therapy, with rotation and percussion',2,'FNE','PM','In Commercial Distribution','2023-01-25'),
('10050059','Hill-Rom Holdings Inc','Welch Allyn Connex VSM 6000','VSM 6000+','901060','Vital signs monitor, spot-check, with connectivity',2,'DQA','AN','In Commercial Distribution','2022-05-30'),
('10050060','Hillrom','RetinaVue 700','RV700','RV700-B','Fundus camera, imager, non-mydriatic, portable',2,'HKI','OP','In Commercial Distribution','2021-12-08'),

-- ===== CANON / TOSHIBA (acquired, dual naming) =====
('10050061','Canon Medical Systems Corporation','Aquilion ONE PRISM','ONE PRISM','?"CXL-40G3','Computed tomography system, 320-row, wide area detector',2,'JAK','RA','In Commercial Distribution','2023-06-01'),
('10050062','Toshiba Medical Systems Corporation','Aquilion Prime SP','Prime SP i','CXL-30G','Computed tomography system, 160-slice, with iterative reconstruction',2,'JAK','RA','Not in Commercial Distribution','2020-02-14'),
('10050063','Canon Medical Systems Corporation','Aplio i800','i800 v6','TUS-AI800','Diagnostic ultrasound system, premium, with SMI micro-flow imaging',2,'IYO','RA','In Commercial Distribution','2022-07-20'),
('10050064','Toshiba Medical Systems Corporation','Xario 200','Xario 200G','TUS-X200','Diagnostic ultrasound system, mid-range, general purpose',2,'IYO','RA','Not in Commercial Distribution','2019-04-10'),

-- ===== ZOLL (defibrillators and temperature management) =====
('10050065','ZOLL Medical Corporation','R Series Plus','R Series v12.4','9650-000-50','Defibrillator/monitor, professional, with See-Thru CPR and pacing',3,'DRE','CV','In Commercial Distribution','2022-08-22'),
('10050066','ZOLL Medical Corporation','Thermogard XP','TG XP v3','TGXP-US','Intravascular temperature management system, catheter-based',2,'KMG','AN','In Commercial Distribution','2023-03-18'),
('10050067','ZOLL Medical Corporation','AED 3','AED 3 BLS','8000-001250','Automated external defibrillator, public access, with Real CPR Help',3,'MKJ','CV','In Commercial Distribution','2022-01-28'),

-- ===== MASIMO (monitoring) =====
('10050068','Masimo Corporation','Root','Root v3.2','3719','Patient monitoring and connectivity platform, modular, bedside',2,'DQA','AN','In Commercial Distribution','2023-04-05'),
('10050069','Masimo Corporation','Radical-7','Radical-7 Color','3704','Pulse oximeter, bedside, with rainbow SET multi-wavelength technology',2,'DQA','AN','In Commercial Distribution','2022-06-10'),
('10050070','Masimo Corporation','Rad-97','Rad-97 v2','3850','Pulse oximeter, tabletop, with tetherless sensor capability',2,'DQA','AN','In Commercial Distribution','2022-11-30'),

-- ===== MINDRAY (monitoring and imaging) =====
('10050071','Shenzhen Mindray Bio-Medical','BeneVision N22','N22','115-033108-00','Patient monitor, bedside, high-acuity, modular',2,'MEC','AN','In Commercial Distribution','2023-02-20'),
('10050072','Mindray DS USA Inc','BeneVision N1','N1','115-053454-00','Transport patient monitor, compact, with touchscreen',2,'MEC','AN','In Commercial Distribution','2022-09-15'),
('10050073','Shenzhen Mindray Bio-Medical','Resona I9','Resona I9','DG6-A000005','Diagnostic ultrasound system, premium, with zone sonography',2,'IYO','RA','In Commercial Distribution','2023-05-28'),
('10050074','Mindray DS USA Inc','SV300','SV300 v3','SV300-001','Critical care ventilator, invasive and noninvasive, with PRVC',2,'MNR','AN','In Commercial Distribution','2022-04-22'),

-- ===== GETINGE / MAQUET (OR and ICU) =====
('10050075','Getinge AB','Servo-u','Servo-u v2.2','6694020','Critical care ventilator, invasive, with NAVA neural control',2,'MNR','AN','In Commercial Distribution','2023-01-15'),
('10050076','MAQUET Medical Systems','FLOW-i','FLOW-i C30','6688042','Anesthesia delivery system, with electronic gas mixer and circle system',2,'BSZ','AN','In Commercial Distribution','2022-03-08'),
('10050077','Getinge AB','Tegris','Tegris v5','TS100','Operating room integration system, video and data management',1,'QMT','SU','In Commercial Distribution','2022-08-14'),

-- ===== NIHON KOHDEN =====
('10050078','Nihon Kohden Corporation','Vismo PVM-4763','PVM-4763','PVM-4763','Patient monitor, bedside, 6-parameter, with CO2 sidestream',2,'MEC','AN','In Commercial Distribution','2023-06-05'),
('10050079','Nihon Kohden America','NK AED-3100','AED-3100 K','AED-3100K','Automated external defibrillator, biphasic, with CPR coaching',3,'MKJ','CV','In Commercial Distribution','2022-02-18'),
('10050080','Nihon Kohden Corporation','WEE-1000','WEE-1000 v3','WEE-1000','EEG system, digital, full montage, with artifact reduction',2,'GWG','NE','In Commercial Distribution','2022-10-30'),

-- ===== SMITH+NEPHEW (surgical) =====
('10050081','Smith & Nephew plc','CORI Surgical System','CORI v2.0','72205389','Robotic-assisted surgical platform, orthopedic, handheld',2,'HRS','OR','In Commercial Distribution','2023-04-12'),
('10050082','Smith and Nephew Inc','DYONICS POWER II','POWER II','72200584','Powered surgical instrument, arthroscopic shaver, small joint',1,'HBJ','OR','In Commercial Distribution','2022-01-05'),
('10050083','Smith & Nephew plc','1000XL Camera System','1000XL HD','72210100','Endoscopic camera system, 4K, with integrated LED illumination',2,'GCJ','GU','In Commercial Distribution','2022-07-18'),

-- ===== OLYMPUS (endoscopy) =====
('10050084','Olympus Corporation of the Americas','EVIS X1','CV-1500','N5384730','Video processor, endoscopic, with AI-assisted polyp detection',2,'FEB','GU','In Commercial Distribution','2023-02-28'),
('10050085','Olympus Medical Systems Corp','TJF-Q190V','Q190V','N5419830','Duodenoscope, therapeutic, side-viewing, with elevator',2,'FDT','GU','In Commercial Distribution','2022-05-14'),
('10050086','Olympus Corporation of the Americas','GIF-HQ190','HQ190','N5426130','Gastroscope, diagnostic, high-definition, with near focus',2,'FDS','GU','In Commercial Distribution','2022-11-08'),

-- ===== HAMILTON MEDICAL (ventilators) =====
('10050087','Hamilton Medical AG','Hamilton C6','C6 v3.0','161006','Critical care ventilator, invasive and noninvasive, with INTELLiVENT-ASV',2,'MNR','AN','In Commercial Distribution','2023-05-15'),
('10050088','Hamilton Medical Inc','Hamilton T1','T1 v3.0','161003','Transport and ICU ventilator, turbine-driven, with integrated suction',2,'MNR','AN','In Commercial Distribution','2022-06-25'),

-- ===== WELCH ALLYN / BAXTER / MISC SPOT-CHECK =====
('10050089','Welch Allyn Inc','Spot Vital Signs 4400','VSM 4400','44WT-B','Vital signs device, spot-check, with SureBP technology',2,'DQA','AN','In Commercial Distribution','2021-09-20'),
('10050090','Spacelabs Healthcare','Xprezzon','Xprezzon v1.06','91393','Patient monitor, bedside, touchscreen, modular with wireless',2,'MEC','AN','In Commercial Distribution','2022-04-05'),

-- ===== VARIOUS SPECIALTY DEVICES =====
('10050091','Steris plc','Amsco Century V-160H','V-160H','V-160H','Steam sterilizer, prevacuum, large-capacity, surgical instrument processing',2,'FLL','SU','In Commercial Distribution','2022-08-01'),
('10050092','Steris Corporation','Harmony aIR','Harmony aIR 600','444002','Surgical light, LED, ceiling-mounted, with camera integration',1,'FSZ','SU','In Commercial Distribution','2023-03-22'),
('10050093','Drager Medical Inc','Isolette C2000','C2000 v3','C2000','Infant incubator, intensive care, with servo-controlled humidity',2,'KNA','PE','In Commercial Distribution','2022-02-10'),
('10050094','Natus Medical Inc','ALGO 5','ALGO 5 v2','585-AABR2','Newborn hearing screener, automated auditory brainstem response',2,'HNO','EN','In Commercial Distribution','2021-11-15'),
('10050095','Hologic Inc','Dimensions','Selenia Dimensions','?"M-IV-SDB','Mammography system, digital, 3D tomosynthesis, with C-View',2,'MYN','RA','In Commercial Distribution','2022-07-08'),
('10050096','Fujifilm Healthcare Americas','FDR D-EVO III','D-EVO III GL','DR-ID 1200SE','Digital radiography detector, wireless, cesium iodide',2,'QKQ','RA','In Commercial Distribution','2023-01-12'),
('10050097','Fujifilm Medical Systems USA','FCR Capsula XLII','Capsula XLII','CR-IR 391','Computed radiography system, general purpose, multi-plate reader',2,'MQB','RA','Not in Commercial Distribution','2019-05-30'),
('10050098','Teleflex Incorporated','Arrow EZ-IO','EZ-IO G3','9002-PLUS','Intraosseous vascular access system, power-driven, for emergencies',2,'KYT','SU','In Commercial Distribution','2022-09-28'),
('10050099','Vyaire Medical Inc','AVEA CVS','AVEA CVS v4.8','19100-001','Critical care ventilator, comprehensive, with esophageal monitoring',2,'MNR','AN','In Commercial Distribution','2022-06-14'),
('10050100','Vyaire Medical Inc','Jaeger MasterScreen PFT','MS PFT Pro','794100','Pulmonary function testing system, body plethysmograph',2,'BZG','PU','In Commercial Distribution','2021-08-22');
