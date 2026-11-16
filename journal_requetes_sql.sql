JOURNAL DES REQUÊTES SQL - Projet DVF Lyon (BigQuery)
Reconstitué le 2026-11-11

MODE D'EMPLOI
- Remplacer VOTRE-PROJET par l'identifiant du projet BigQuery utilisé
  (Rechercher / Remplacer dans tout le fichier).
- Exécuter les requêtes dans l'ordre. Les CREATE OR REPLACE TABLE ne
  produisent aucun tableau : elles créent une table dans le dataset.
- Dataset : dvf_lyon
- Table brute : dvf_69 (459 384 lignes, 17 colonnes), issue de R
  (voir 01_filtrage_rhone.R)

SOURCE DES DONNÉES
DVF géolocalisées (data.gouv.fr), fichier unique juillet 2021 - juin 2026,
filtré sur le département du Rhône (code 69).

ENTONNOIR DES DONNÉES
  459 384  lignes brutes du Rhône
  114 301  lignes d'appartements (toutes natures de mutation)
   80 045  ventes d'appartements, une ligne par vente (appartements_propres)
   79 501  ventes retenues après bornes de prix et de surface (appartements_analyse)


00. CONTRÔLES APRÈS IMPORT

00a. Schéma de la table brute
SELECT column_name, data_type
FROM `VOTRE-PROJET.dvf_lyon.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'dvf_69';

 00b. Nombre de lignes (résultat : 459 384)
SELECT COUNT(*) AS nb_lignes FROM `VOTRE-PROJET.dvf_lyon.dvf_69`;

00c. Aperçu
SELECT * 
FROM `VOTRE-PROJET.dvf_lyon.dvf_69` 
LIMIT 5;

Constat : valeur_fonciere, surface_reelle_bati, nombre_pieces_principales,
surface_terrain, longitude et latitude sont importées en STRING, car les
valeurs manquantes sont écrites "NA" (marqueur de R). Conversion par
SAFE_CAST dans l'étape 04.


01. EXPLORATION : TYPES DE BIENS

SELECT type_local, COUNT(*) AS nb
FROM `VOTRE-PROJET.dvf_lyon.dvf_69`
GROUP BY type_local
ORDER BY nb DESC;

Résultat : Dépendance 181 129 ; Appartement 114 301 ; NA 92 302 ;
Maison 41 222 ; Local industriel, commercial ou assimilé 30 430.
Ce sont des lignes, pas des ventes (une vente peut avoir plusieurs lignes).


02. EXPLORATION : NATURES DE VENTE

SELECT nature_mutation, COUNT(*) AS nb
FROM `VOTRE-PROJET.dvf_lyon.dvf_69`
GROUP BY nature_mutation
ORDER BY nb DESC;

Résultat : Vente 414 758 ; Vente en l'état futur d'achèvement 40 597 ;
Echange 2 839 ; Adjudication 764 ; Vente terrain à bâtir 391 ;
Expropriation 35.


03. EXPLORATION : COMMUNES DE LYON

SELECT nom_commune, COUNT(*) AS nb
FROM `VOTRE-PROJET.dvf_lyon.dvf_69`
WHERE nom_commune LIKE 'Lyon%'
GROUP BY nom_commune
ORDER BY nom_commune;

Résultat : Lyon est découpé en arrondissements (Lyon 1Er, Lyon 2Eme, ...
Lyon 9Eme). Le plus actif : Lyon 3Eme (23 802 lignes) ; le moins : Lyon 1Er
(5 537 lignes).


04. NETTOYAGE : TABLE appartements_propres

Règles :
 1. Ventes classiques uniquement (nature_mutation = 'Vente'), hors VEFA,
    échanges, adjudications, expropriations.
 2. Appartements uniquement (type_local = 'Appartement').
 3. Une ligne par vente : on garde les ventes qui contiennent exactement
    un appartement et aucune maison ni local commercial (les dépendances
    sont tolérées).
 4. Conversion des types (SAFE_CAST) : les "NA" deviennent NULL.
 5. Prix et surface valides (> 0).

CREATE OR REPLACE TABLE `VOTRE-PROJET.dvf_lyon.appartements_propres` AS
WITH base AS (
  SELECT
    id_mutation,
    date_mutation,
    EXTRACT(YEAR FROM date_mutation) AS annee,
    SAFE_CAST(valeur_fonciere AS FLOAT64) AS valeur_fonciere,
    code_postal,
    code_commune,
    nom_commune,
    type_local,
    SAFE_CAST(surface_reelle_bati AS FLOAT64) AS surface,
    SAFE_CAST(nombre_pieces_principales AS INT64) AS pieces,
    SAFE_CAST(longitude AS FLOAT64) AS longitude,
    SAFE_CAST(latitude AS FLOAT64) AS latitude
  FROM `VOTRE-PROJET.dvf_lyon.dvf_69`
  WHERE nature_mutation = 'Vente'
),
flags AS (
  SELECT
    id_mutation,
    COUNTIF(type_local = 'Appartement') AS nb_appart,
    COUNTIF(type_local = 'Maison' OR type_local LIKE 'Local%') AS nb_autres_batis
  FROM base
  GROUP BY id_mutation
)
SELECT
  b.id_mutation, b.date_mutation, b.annee, b.valeur_fonciere,
  b.code_postal, b.code_commune, b.nom_commune,
  b.surface, b.pieces, b.longitude, b.latitude,
  ROUND(b.valeur_fonciere / b.surface, 0) AS prix_m2
FROM base b
JOIN flags f USING (id_mutation)
WHERE b.type_local = 'Appartement'
  AND f.nb_appart = 1
  AND f.nb_autres_batis = 0
  AND b.valeur_fonciere > 0
  AND b.surface > 0;


05. CONTRÔLES la table appartements_propres

05a. Unicité : une ligne par vente
SELECT COUNT(*) AS nb_lignes, COUNT(DISTINCT id_mutation) AS nb_ventes
FROM `VOTRE-PROJET.dvf_lyon.appartements_propres`;
Résultat : 80 045 lignes et 80 045 ventes (dédoublonnage validé).

05b. Distribution du prix au m2 (repérage des valeurs aberrantes)
SELECT
  COUNT(*) AS nb,
  MIN(prix_m2) AS minimum,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(1)]  AS p1,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(5)]  AS p5,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(25)] AS p25,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS mediane,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(75)] AS p75,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(95)] AS p95,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(99)] AS p99,
  MAX(prix_m2) AS maximum
FROM `VOTRE-PROJET.dvf_lyon.appartements_propres`;
Résultat : min 0 ; p1 909 ; p5 1 711 ; p25 2 911 ; médiane 3 858 ;
p75 4 835 ; p95 6 428 ; p99 7 918 ; max 5 202 439.
Constat : cœur de distribution plausible, extrêmes aberrants.


06. BORNES : TABLE appartements_analyse

Bornes retenues (choix de jugement, testées en 09) :
 - surface entre 9 et 250 m2
 - prix au m2 entre 500 et 12 000 EUR
Ajout de la colonne arrondissement (1 à 9) pour Lyon.

CREATE OR REPLACE TABLE `VOTRE-PROJET.dvf_lyon.appartements_analyse` AS
SELECT *,
  IF(REGEXP_CONTAINS(nom_commune, r'^Lyon \d'),
     CAST(REGEXP_EXTRACT(nom_commune, r'^Lyon (\d)') AS INT64),
     NULL) AS arrondissement
FROM `VOTRE-PROJET.dvf_lyon.appartements_propres`
WHERE surface BETWEEN 9 AND 250
  AND prix_m2 BETWEEN 500 AND 12000;

06b. Contrôle après bornes
SELECT
  COUNT(*) AS nb_ventes,
  MIN(prix_m2) AS prix_min,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS mediane,
  MAX(prix_m2) AS prix_max,
  MIN(surface) AS surface_min,
  MAX(surface) AS surface_max
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`;
Résultat : 79 501 ventes (544 retirées, soit 0,7 %) ; prix 500 à 11 894 ;
médiane 3 867 ; surface 9 à 250.


07. ANALYSE : PRIX PAR SEMESTRE (Lyon / reste du Rhône)

CREATE OR REPLACE TABLE `VOTRE-PROJET.dvf_lyon.prix_par_semestre` AS
SELECT
  CONCAT(CAST(annee AS STRING), '-S', IF(EXTRACT(MONTH FROM date_mutation) <= 6, '1', '2')) AS semestre,
  IF(arrondissement IS NOT NULL, 'Lyon', 'Reste du Rhône') AS territoire,
  COUNT(*) AS nb_ventes,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS prix_median_m2,
  APPROX_QUANTILES(surface, 100)[OFFSET(50)] AS surface_mediane
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
GROUP BY semestre, territoire;

 Affichage / export CSV (07_analyse_prix_par_semestre.csv)
SELECT * 
FROM `VOTRE-PROJET.dvf_lyon.prix_par_semestre` 
ORDER BY semestre, territoire;

Résultat clé : Lyon passe de 5 133 EUR/m2 (2022-S2) à 4 419 (2026-S1),
soit environ -14 %, avec une stabilisation depuis 2024. Reste du Rhône :
3 571 (2022-S2) -> plancher 3 136 (2024-S1) -> 3 211 (2026-S1).


08. ANALYSE : PRIX PAR ARRONDISSEMENT DE LYON

CREATE OR REPLACE TABLE `VOTRE-PROJET.dvf_lyon.prix_par_arrondissement` AS
SELECT
  arrondissement,
  COUNT(*) AS nb_ventes,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS prix_median_m2,
  APPROX_QUANTILES(IF(annee = 2022, prix_m2, NULL), 100)[OFFSET(50)] AS mediane_2022,
  APPROX_QUANTILES(IF(annee = 2025, prix_m2, NULL), 100)[OFFSET(50)] AS mediane_2025
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
WHERE arrondissement IS NOT NULL
GROUP BY arrondissement;

Affichage / export CSV (08_analyse_prix_par_arrondissement.csv)
SELECT * FROM `VOTRE-PROJET.dvf_lyon.prix_par_arrondissement` ORDER BY arrondissement;

Résultat clé (2022 -> 2025) : 1er -18 %, 2e -18 %, 4e -14 %, 6e -12 %,
3e -12 %, 5e -11 %, 9e -11 %, 7e -10 %, 8e -8 %.
À noter : le 1er et le 2e comptent le moins de ventes (environ 2 100 chacun).


09. ROBUSTESSE DES BORNES (médiane de Lyon)

WITH lyon AS (
  SELECT *
  FROM `VOTRE-PROJET.dvf_lyon.appartements_propres`
  WHERE REGEXP_CONTAINS(nom_commune, r'^Lyon \d')
)
SELECT 'Étroites : 1000-10000 €/m2, 15-200 m2' AS scenario,
       COUNT(*) AS nb_ventes,
       APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS mediane_lyon
FROM lyon WHERE prix_m2 BETWEEN 1000 AND 10000 AND surface BETWEEN 15 AND 200
UNION ALL
SELECT 'Retenues : 500-12000 €/m2, 9-250 m2', COUNT(*),
       APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)]
FROM lyon WHERE prix_m2 BETWEEN 500 AND 12000 AND surface BETWEEN 9 AND 250
UNION ALL
SELECT 'Larges : 200-20000 €/m2, 5-400 m2', COUNT(*),
       APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)]
FROM lyon WHERE prix_m2 BETWEEN 200 AND 20000 AND surface BETWEEN 5 AND 400;

Résultat : médiane de Lyon 4 722 (larges), 4 722 (retenues), 4 719
(étroites) : écart de 3 EUR/m2. Les conclusions sont robustes au choix
des bornes.


10. ANALYSE : PRIX PAR NOMBRE DE PIÈCES

CREATE OR REPLACE TABLE `VOTRE-PROJET.dvf_lyon.prix_par_pieces` AS
SELECT
  IF(pieces >= 5, '5 et plus', CAST(pieces AS STRING)) AS pieces,
  IF(arrondissement IS NOT NULL, 'Lyon', 'Reste du Rhône') AS territoire,
  COUNT(*) AS nb_ventes,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS prix_median_m2,
  APPROX_QUANTILES(surface, 100)[OFFSET(50)] AS surface_mediane
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
WHERE pieces >= 1
GROUP BY pieces, territoire;

 Affichage / export CSV (10_analyse_prix_par_pieces.csv)
SELECT * FROM `VOTRE-PROJET.dvf_lyon.prix_par_pieces` ORDER BY territoire, pieces;

Résultat clé : le prix au m2 baisse quand le nombre de pièces augmente ;
la prime de Lyon sur le reste du Rhône va de +26 % (1 pièce) à +54 %
(5 pièces et plus). 102 ventes sans nombre de pièces exclues (0,13 %).


11. HARMONISATION DES COMMUNES ET TABLE prix_par_commune

Problème : plusieurs libellés pour un même code commune.
Règle : regroupement par code_commune, libellé de la vente la plus récente.

11a. Diagnostic Oullins
SELECT nom_commune, code_commune,
       MIN(date_mutation) AS premiere_vente,
       MAX(date_mutation) AS derniere_vente,
       COUNT(*) AS nb_ventes
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
WHERE nom_commune LIKE 'Oullins%'
GROUP BY nom_commune, code_commune
ORDER BY premiere_vente;
Résultat : 3 libellés pour le code 69149 (Oullins, Oullins-Pierre-Bénite,
Oullins Pierre Benite), 989 + 250 + 650 ventes.

11b. Codes commune ayant plusieurs libellés
SELECT code_commune,
       COUNT(DISTINCT nom_commune) AS nb_libelles,
       STRING_AGG(DISTINCT nom_commune, ' | ') AS libelles
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
GROUP BY code_commune
HAVING COUNT(DISTINCT nom_commune) > 1;
Résultat : 4 codes concernés (69094, 69096, 69114, 69149).

11c. Diagnostic détaillé des codes 69094, 69096, 69114
SELECT code_commune, nom_commune,
       MIN(date_mutation) AS premiere_vente,
       MAX(date_mutation) AS derniere_vente,
       COUNT(*) AS nb_ventes,
       APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS prix_median_m2,
       ROUND(AVG(latitude), 3) AS lat_moy,
       ROUND(AVG(longitude), 3) AS long_moy
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
WHERE code_commune IN (69094, 69096, 69114)
GROUP BY code_commune, nom_commune
ORDER BY code_commune, premiere_vente;
Résultat : Grigny / Grigny-sur-Rhône et Porte des Pierres Dorées : libellés
qui se succèdent (changements d'écriture). 69094 : 3 ventes "Craponne"
(probable étiquetage erroné) contre 128 "Grezieu-la-Varenne".

11d. (Facultatif, non exécuté) Un même nom associé à plusieurs codes
SELECT nom_commune,
       COUNT(DISTINCT code_commune) AS nb_codes,
       STRING_AGG(DISTINCT CAST(code_commune AS STRING), ' | ') AS codes
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
GROUP BY nom_commune
HAVING COUNT(DISTINCT code_commune) > 1;

11. Table finale prix_par_commune (communes hors Lyon, au moins 200 ventes)
CREATE OR REPLACE TABLE `VOTRE-PROJET.dvf_lyon.prix_par_commune` AS
SELECT
  code_commune,
  ARRAY_AGG(nom_commune ORDER BY date_mutation DESC LIMIT 1)[OFFSET(0)] AS commune,
  COUNT(*) AS nb_ventes,
  APPROX_QUANTILES(prix_m2, 100)[OFFSET(50)] AS prix_median_m2,
  APPROX_QUANTILES(IF(annee = 2022, prix_m2, NULL), 100)[OFFSET(50)] AS mediane_2022,
  APPROX_QUANTILES(IF(annee = 2025, prix_m2, NULL), 100)[OFFSET(50)] AS mediane_2025
FROM `VOTRE-PROJET.dvf_lyon.appartements_analyse`
WHERE arrondissement IS NULL
GROUP BY code_commune
HAVING COUNT(*) >= 200;

Affichage / export CSV (11_analyse_prix_par_commune.csv)
SELECT * FROM `VOTRE-PROJET.dvf_lyon.prix_par_commune` ORDER BY nb_ventes DESC;

11e. Contrôle des doublons (doit ne renvoyer aucune ligne)
SELECT commune, COUNT(*) AS nb
FROM `VOTRE-PROJET.dvf_lyon.prix_par_commune`
GROUP BY commune
HAVING COUNT(*) > 1;

Résultat : 35 communes ; Oullins-Pierre-Bénite regroupée sur une seule
ligne (1 889 ventes), Grigny-sur-Rhône sur une seule ligne (388 ventes).
Les évolutions 2022 -> 2025 ne sont fiables que pour les communes de plus
de 1 000 ventes (peu de ventes par année sinon).


LIMITES À MENTIONNER DANS LE PROJET

- Périmètre : ventes classiques d'appartements, un appartement par vente,
  hors logements neufs (VEFA).
- Médianes non corrigées des effets de composition (taille, âge, étage).
- 2021 (juillet-décembre) et 2026 (janvier-juin) sont des années
  incomplètes : analyse par semestre.
- Description des évolutions, sans lien de causalité démontré.
- Petits échantillons : 1er et 2e arrondissements, communes de moins de
  1 000 ventes.
