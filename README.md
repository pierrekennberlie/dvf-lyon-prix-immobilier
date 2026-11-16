Prix de l'immobilier dans le Rhône (2021-2026)

Analyse des prix des appartements dans le Rhône et à Lyon à partir des données DVF (Demandes de valeurs foncières)avec SQL (BigQuery), R et un dashboard Tableau Public.

Dashboard interactif : https://public.tableau.com/views/PrixdelimmobilierdansleRhne-DVF2021-2026/Tableaudebord1

Auteure : Kenn Berlie Pierre

Objectif

Mesurer comment ont évolué les prix au m² des appartements entre juillet 2021 et juin 2026 et comparer Lyon (par arrondissement), le reste du Rhône (par commune) et les tailles de logement.

Données
Source : DVF géolocalisées (DGFiP), publiées en open data sur data.gouv.fr. Fichier unique juillet 2021 - juin 2026.
Périmètre : Département du Rhône (69), soit 459 384 lignes brutes.
Les données brutes ne sont pas versionnées dans ce dépôt (fichiers trop volumineux) : voir « Reproduire l'analyse ».

Méthode
R (filtrage_rhone.R) : lecture du fichier national par morceaux, filtrage sur le Rhône, sélection de 17 colonnes, export compressé.
SQL / BigQuery (journal_requetes_sql) : contrôle de la base, nettoyage, dédoublonnage par vente, calcul des médianes, tables d'analyse. Le journal reprend chaque requête avec son résultat.

Tableau Public : 6 visualisations assemblées dans un dashboard interactif (infobulles, filtre par clic sur un arrondissement).

Règles de nettoyage
Une vente peut occuper plusieurs lignes : dédoublonnage par id_mutation.
Ventes conservées : nature « Vente » avec un seul appartement et aucune maison ni local commercial ou industriel dans la même vente. Sont exclues les ventes en l'état futur d'achèvement, les échanges, les adjudications et les expropriations.
Valeurs aberrantes : surface entre 9 et 250 m², prix entre 500 et 12 000 €/m².
Communes regroupées par code commune car les libellés changent au fil des années (par exemple Oullins sous trois noms).
Médiane plutôt que moyenne pour limiter l'effet des valeurs extrêmes.

Entonnoir des données

Étape : 	                                             
Lignes brutes du Rhône	                                   459 384,
lignes d'appartements (toutes natures de mutation)	114 301,
ventes d'appartements (une ligne par vente)	             80 045,
ventes retenues après bornes de prix et de surface	 79 501.

Les bornes retirent 544 ventes (0,7 %). Test de robustesse : la médiane de Lyon varie de 3 €/m² selon que les bornes sont étroites, retenues ou larges (4 719 à 4 722 €/m²).

Résultats principaux
Lyon : le prix médian passe d'environ 5 133 €/m² (2022-S2) à 4 419 €/m² (2026-S1), soit environ -14 % avec une stabilisation depuis 2024.

Reste du Rhône : environ 3 571 €/m² (2022-S2), un plancher à 3 136 €/m² (2024-S1), puis 3 211 €/m² (2026-S1).

Arrondissements de Lyon, 2022 à 2025 : baisse dans les 9 arrondissements, de -8 % (8e) à -18 % (1er et 2e). Ces deux arrondissements comptent aussi le moins de ventes (environ 2 100 chacun).

Nombre de pièces : le prix au m² baisse quand le nombre de pièces augmente. La prime de Lyon sur le reste du Rhône va de +26 % (1 pièce) à +54 % (5 pièces et plus).
Communes : parmi les communes de plus de 1 000 ventes, toutes sont en baisse entre 2022 et 2025.

Limites
Analyse descriptive : elle décrit des évolutions de prix, elle n'en établit pas les causes.

Effet de composition : la médiane peut bouger parce que le type de biens vendus change (taille, quartier, état) pas seulement parce que les prix varient.

Les évolutions 2022 à 2025 par commune ne sont lues que pour les communes de plus de 1 000 ventes ; en dessous, les échantillons annuels sont trop petits.
Une vente peut inclure des dépendances (cave, parking) dans son prix, ce qui n'est pas isolé ici.
Les années 2021 et 2026 sont incomplètes (la période couvre juillet 2021 à juin 2026) : l'analyse temporelle se fait par semestre.

Structure du dépôt

SQL      : journal_requetes_sql.sql   requêtes BigQuery commentées

R        : filtrage_rhone.R           extraction du Rhône depuis le fichier national

Résultats:  prix_semestre.csv, prix_par_arrondissement.csv,
            prix_par_pièces.csv, prix_par_commune.csv
            tables agrégées utilisées dans le dashboard

Reproduire l'analyse

Télécharger le fichier DVF « juillet 2021 - juin 2026 » sur data.gouv.fr.

Lancer filtrage_rhone.R (adapter le chemin du fichier téléchargé) : il produit dvf_69_light.csv.gz.

Importer ce fichier dans BigQuery (dataset dvf_lyon, table dvf_69).

Dans journal_requetes_sql.sql, remplacer VOTRE-PROJET par l'identifiant de votre projet BigQuery, puis exécuter les requêtes dans l'ordre.

Exporter les tables d'analyse en CSV et les charger dans Tableau Public.
