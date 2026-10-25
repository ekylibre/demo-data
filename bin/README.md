# Runners d'extrapolation (campagne N → N+k)

Scripts Ruby autonomes qui étendent le dataset `demo-data/demo/` d'une campagne
agricole vers les suivantes. Sans Rails, sans Bundler lourd : stdlib Ruby (`csv`,
`pathname`, `fileutils`) suffit.

## Déterminisme et idempotence

- Chaque runner lit son fichier source (année max présente) et écrit la cible
  (année `TO`) sans toucher au reste.
- Les runners sont **idempotents** : rejouer `TO=2025` quand 2025 est déjà
  présent est un no-op.
- Pas de random non-seedé (brainstorm Q-A : "duplique sans rotation").
- Encodages des sources préservés : TELEPAC XML en ISO-8859-1, Istea `.TXT` en
  ISO-8859-1, CSV alamano en UTF-8.

## Scripts

| Script | Rôle |
|---|---|
| `extrapolate_all.rb` | Orchestrateur : rejoue tous les runners de `FROM_TELEPAC+1` à `TO` |
| `extrapolate_telepac.rb` | Duplique `telepac/<FROM>/statement.xml` en bumpant `fichier-xsd` à `<TO>` |
| `extrapolate_operations.rb` | Alamano CSV (sales, purchases, payments, payslips, cash_transfers, interventions, incoming_harvests) : append des lignes décalées |
| `extrapolate_compta.rb` | Istea `journal_entries.TXT` : écritures de l'année max dupliquées vers `TO` |
| `extrapolate_cheptel.rb` | **No-op documenté** : synel/milklic/lilco/bovins_croissance sont trop spécifiques pour une duplication naïve. Voir commentaires du script. |

## Usage courant

```bash
# Étendre tout le dataset jusqu'à la campagne 2026 incluse :
TO=2026 ruby bin/extrapolate_all.rb

# Lancer un seul runner :
FROM=2023 TO=2024 ruby bin/extrapolate_telepac.rb
TO=2026 ruby bin/extrapolate_operations.rb
TO=2026 ruby bin/extrapolate_compta.rb
```

## Après extrapolation

Les fichiers sont écrits sous `demo/`. Pour les faire consommer par le first_run
Ekylibre, synchroniser le dossier :

```bash
rsync -a --exclude='.git' demo-data/demo/ ekylibre/db/first_runs/demo/
```

(Un script de sync + CI check sera formalisé à l'étape 6 du brief refresh.)
