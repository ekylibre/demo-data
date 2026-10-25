#!/usr/bin/env ruby
# frozen_string_literal: true

# Extrapole les CSVs opérationnels de alamano/ vers une année cible.
# Pour chaque CSV, trouve l'année la plus récente déjà présente, et duplique
# ses lignes vers TO en décalant les dates. Idempotent : saute un fichier
# si TO est déjà présent dedans. Pas de rotation (brainstorm Q-A).
#
# Usage :
#   TO=2024 ruby bin/extrapolate_operations.rb
#   TO=2025 ruby bin/extrapolate_operations.rb
#   TO=2026 ruby bin/extrapolate_operations.rb
#
# Les CSVs touchés sont :
#   - sales.csv, purchases.csv, incoming_payments.csv, outgoing_payments.csv,
#     payslips.csv, cash_transfers.csv : séparateur `,`, dates ISO (YYYY-MM-DD).
#   - interventions.csv, incoming_harvests.csv : séparateur `;`, dates FR (DD/MM/YYYY).
#   - interventions.csv embarque aussi une colonne "Campagne" bumpée.

require 'csv'
require 'date'
require 'pathname'

TO = (ENV['TO'] || '').to_i
abort 'TO env var is required (e.g. TO=2024)' if TO.zero?

TODAY = Date.today
ALAMANO = Pathname.new(__dir__).parent.join('demo', 'alamano')

ISO_FILES = {
  'sales.csv' => { sep: ',', date_cols: [0] },
  'purchases.csv' => { sep: ',', date_cols: [0] },
  'incoming_payments.csv' => { sep: ',', date_cols: [0, 5] },
  'outgoing_payments.csv' => { sep: ',', date_cols: [0, 5] },
  'payslips.csv' => { sep: ',', date_cols: [0, 1] },
  'cash_transfers.csv' => { sep: ',', date_cols: [0] }
}.freeze

# interventions.csv n'est pas dupliqué : chaque intervention est liée à des
# ActivityProduction/CultivableZone cohérentes avec sa campagne. Une
# duplication naïve plante `interventions_exchanger.rb:201` quand le support
# ne retrouve pas de production matching dans la campagne cible.
FR_FILES = {
  'incoming_harvests.csv' => { sep: ';', date_cols: [1] }
}.freeze

def shift_iso(date_str, years)
  return date_str unless date_str =~ /\A(\d{4})-(\d{2})-(\d{2})\z/
  "#{$1.to_i + years}-#{$2}-#{$3}"
end

def shift_fr(date_str, years)
  return date_str unless date_str =~ %r{\A(\d{2})/(\d{2})/(\d{4})\z}
  "#{$1}/#{$2}/#{$3.to_i + years}"
end

def date_from_iso(s)
  return nil unless s =~ /\A(\d{4})-(\d{2})-(\d{2})\z/
  Date.new($1.to_i, $2.to_i, $3.to_i)
rescue ArgumentError
  nil
end

def date_from_fr(s)
  return nil unless s =~ %r{\A(\d{2})/(\d{2})/(\d{4})\z}
  Date.new($3.to_i, $2.to_i, $1.to_i)
rescue ArgumentError
  nil
end

def year_of_iso(date_str)
  return nil unless date_str =~ /\A(\d{4})-/
  $1.to_i
end

def year_of_fr(date_str)
  return nil unless date_str =~ %r{\A\d{2}/\d{2}/(\d{4})\z}
  $1.to_i
end

def bump_reference_year(value, from, to)
  return value unless value.is_a?(String)
  value.sub(/\A#{Regexp.escape(from.to_s)}/, to.to_s)
end

def process(path, config, to, year_fn, shift_fn, date_fn, iso:)
  rows = CSV.parse(path.read, col_sep: config[:sep], headers: false, liberal_parsing: true)
  header = rows.first
  body = rows.drop(1)
  date_cols = config[:date_cols]
  campaign_col = config[:campaign_col]

  # Toujours purger les lignes dont la date principale est dans le futur :
  # les validations Rails rejettent les ventes/achats/paiements postérieurs à
  # Time.zone.now. Cette passe est idempotente et défensive.
  pruned = 0
  body.reject! do |r|
    d = date_fn.call(r[date_cols.first].to_s)
    future = d && d > TODAY
    pruned += 1 if future
    future
  end

  years = body.map { |r| year_fn.call(r[date_cols.first].to_s) }.compact
  return :no_data if years.empty?

  if years.include?(to)
    result = :skipped_already_done
  else
    from = years.max
    if from >= to
      result = :no_source
    else
      shift = to - from
      source_rows = body.select { |r| year_fn.call(r[date_cols.first].to_s) == from }
      ref_col = header.index { |h| h.to_s =~ /reference|facture/i } if iso

      source_rows.each do |row|
        new_row = row.dup
        date_cols.each do |c|
          v = new_row[c]
          new_row[c] = shift_fn.call(v.to_s, shift) if v && !v.to_s.empty?
        end
        # Skip la ligne si la date principale projetée dépasse aujourd'hui.
        new_date = date_fn.call(new_row[date_cols.first].to_s)
        next if new_date && new_date > TODAY

        new_row[ref_col] = bump_reference_year(new_row[ref_col], from, to) if ref_col
        new_row[campaign_col] = to.to_s if campaign_col && new_row[campaign_col].to_s == from.to_s
        body << new_row
      end
      result = [:appended, from, body.count { |r| year_fn.call(r[date_cols.first].to_s) == to }]
    end
  end

  if pruned.positive? || result.is_a?(Array)
    content = CSV.generate(col_sep: config[:sep], force_quotes: false) do |csv|
      csv << header
      body.each { |r| csv << r }
    end
    path.write(content)
  end

  [result, pruned]
end

def report(name, pair, to)
  result, pruned = pair
  prefix = pruned.positive? ? "✎ #{name}: pruned #{pruned} future row(s)" : nil
  message = if result.is_a?(Array) && result.first == :appended
              _, from, count = result
              "✔ #{name}: #{from} → #{to}, up to #{count} total rows (<=today)"
            elsif result == :skipped_already_done
              "⊘ #{name}: #{to} already present"
            elsif result == :no_source
              "⊘ #{name}: no source year < #{to}"
            elsif result == :no_data
              "⊘ #{name}: empty"
            end
  puts [prefix, message].compact.join(' | ')
end

ISO_FILES.each do |name, config|
  path = ALAMANO.join(name)
  unless path.exist?
    warn "Skip #{name}: file not found"
    next
  end
  pair = process(path, config, TO, method(:year_of_iso), method(:shift_iso), method(:date_from_iso), iso: true)
  report(name, pair, TO)
end

FR_FILES.each do |name, config|
  path = ALAMANO.join(name)
  unless path.exist?
    warn "Skip #{name}: file not found"
    next
  end
  pair = process(path, config, TO, method(:year_of_fr), method(:shift_fr), method(:date_from_fr), iso: false)
  report(name, pair, TO)
end
