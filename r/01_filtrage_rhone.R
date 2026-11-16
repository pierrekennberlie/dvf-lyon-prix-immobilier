
# 01_filtrage_rhone.R
# Projet DVF Lyon : extraction du département du Rhône (69)
# Reconstitué le 2026-11-11

# Source : DVF géolocalisées (data.gouv.fr)
# fichier "DVF juillet 2021 - juin 2026 - fichier unique" (csv.gz)
# Sortie : dvf_69_light.csv.gz (17 colonnes), à importer dans BigQuery (dataset dvf_lyon, table dvf_69)

# À adapter : chemin du fichier téléchargé (variable `fichier_dvf`)

install.packages(c("readr", "dplyr"))   # ( à faire une seule fois)
library(readr)
library(dplyr)

# 1. Fichier national téléchargé sur data.gouv.fr
fichier_dvf <- "~/Downloads/dvf.csv"      # adapter au nom réel du fichier

# 2. Ne garder que le Rhône, lecture par morceaux (fichier très volumineux)
# Toutes les colonnes sont lues en texte pour éviter les erreurs de lecture.
garde_rhone <- DataFrameCallback$new(function(x, pos) {
  filter(x, code_departement == "69")
})

rhone <- read_csv_chunked(
  fichier_dvf,
  callback   = garde_rhone,
  chunk_size = 200000,
  col_types  = cols(.default = col_character())
)

# 3. Contrôles : nombre de lignes (attendu : environ 459 384) et couverture
nrow(rhone)
table(substr(rhone$date_mutation, 1, 7))   # lignes par mois, 2021-07 à 2026-06

# 4. Garder uniquement les colonnes utiles (le fichier complet dépasse
#    la limite de 100 Mo de l'import local dans BigQuery)
colonnes <- c("id_mutation", "date_mutation", "nature_mutation", "valeur_fonciere",
              "adresse_nom_voie", "code_postal", "code_commune", "nom_commune",
              "id_parcelle", "nombre_lots", "lot1_surface_carrez",
              "type_local", "surface_reelle_bati", "nombre_pieces_principales",
              "surface_terrain", "longitude", "latitude")

rhone_light <- rhone %>% select(any_of(colonnes))
ncol(rhone_light)                           # attendu : 17

# 5. Export compressé pour BigQuery
#    Note : write_csv écrit les valeurs manquantes sous la forme "NA", ce qui
#    explique que les colonnes numériques soient reconnues en STRING par
#    BigQuery (conversion par SAFE_CAST dans le fichier SQL, étape 04).
write_csv(rhone_light, "dvf_69_light.csv.gz")
file.size("dvf_69_light.csv.gz") / 1e6      # taille en Mo
getwd()                                     # dossier où le fichier a été écrit
