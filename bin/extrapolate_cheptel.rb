#!/usr/bin/env ruby
# frozen_string_literal: true

# Extrapolation du cheptel — stub documenté.
#
# Les fichiers d'élevage sont trop spécifiques pour être dupliqués naïvement :
#
#   - synel/animaux.csv & inventaire.csv : chaque animal porte sa date de
#     naissance et son numéro d'inventaire. Décaler les dates casserait la
#     cohérence biologique (vêlages, âges). Le cheptel courant est déjà
#     plausible pour 2026 ; on le laisse tel quel.
#
#   - milklic/lait_individuel.csv : header "colonne par date de contrôle"
#     (01/09/23, 01/10/23, …). Prolonger demanderait d'ajouter des colonnes et
#     d'inventer des rendements plausibles — hors scope de la démo.
#
#   - lilco/HistoIP_V.csv : contrôles de qualité du lait tank (Annee;Mois).
#     Extrapolable mais non critique pour l'affichage dashboard 2026.
#
#   - bovins_croissance/perf.csv : contrôles de croissance aux dates de
#     naissance des animaux. Figé.
#
#   - upra/liste_males_reproducteurs.txt : index génétique, pas de dates.
#
# Décision brainstorm (Q-A) : "Duplique sans rotation", mais ici la duplication
# naïve dégraderait les données. Si un besoin métier apparaît (contrôles
# laitiers récents visibles sur la fiche animal), compléter ce fichier.

puts '⊘ cheptel: no-op by design (see comments in bin/extrapolate_cheptel.rb)'
