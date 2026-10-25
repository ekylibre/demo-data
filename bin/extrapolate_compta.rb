#!/usr/bin/env ruby
# frozen_string_literal: true

# Extrapole les écritures comptables Istea vers l'année TO.
# Prend les lignes de l'année max déjà présente dans journal_entries.TXT, les
# duplique en décalant les dates vers TO. Idempotent : saute si TO est déjà
# présent. Encodage ISO-8859-1 préservé.
#
# balance.TXT n'est pas touché : il porte les balances d'ouverture historiques
# (2016–2018 dans la démo) et n'a pas vocation à être étendu année par année.
#
# Usage :
#   TO=2025 ruby bin/extrapolate_compta.rb
#   TO=2026 ruby bin/extrapolate_compta.rb

require 'date'
require 'pathname'

TO = (ENV['TO'] || '').to_i
abort 'TO env var is required (e.g. TO=2025)' if TO.zero?

TODAY = Date.today
ISTEA = Pathname.new(__dir__).parent.join('demo', 'istea')
JE_FILE = ISTEA.join('journal_entries.TXT')
abort "Missing #{JE_FILE}" unless JE_FILE.exist?

raw = JE_FILE.binread.force_encoding('ISO-8859-1')
lines = raw.split("\n", -1)
trailing_newline = lines.last == '' ? lines.pop : nil

# Chaque ligne a `JJ/MM/AAAA` en colonne 3 (index 2) après split(';').
date_of = lambda do |line|
  return nil unless line =~ %r{^[^;]*;[^;]*;(\d{2})/(\d{2})/(\d{4});}
  Date.new($3.to_i, $2.to_i, $1.to_i) rescue nil
end
year_of = ->(line) { d = date_of.call(line); d&.year }

# Purge défensive des écritures datées dans le futur (idempotent).
pruned = 0
lines.reject! do |l|
  d = date_of.call(l)
  future = d && d > TODAY
  pruned += 1 if future
  future
end

years = lines.map { |l| year_of.call(l) }.compact
if years.empty?
  puts "⊘ journal_entries.TXT: no dated line"
  exit 0
end

if years.include?(TO)
  message = "⊘ journal_entries.TXT: #{TO} already present"
else
  from = years.max
  if from >= TO
    message = "⊘ journal_entries.TXT: no source year < #{TO}"
  else
    shift = TO - from
    source_lines = lines.select { |l| year_of.call(l) == from }
    appended_lines = source_lines.map do |l|
      l.sub(%r{^([^;]*;[^;]*;)(\d{2})/(\d{2})/(\d{4})(;)}) do
        "#{$1}#{$2}/#{$3}/#{$4.to_i + shift}#{$5}"
      end
    end
    appended_lines.reject! { |l| (d = date_of.call(l)) && d > TODAY }
    lines.concat(appended_lines)
    message = "✔ journal_entries.TXT: #{from} → #{TO}, +#{appended_lines.size} rows (<=today)"
  end
end

new_content = lines.join("\n")
new_content += "\n" if trailing_newline || !new_content.empty?

JE_FILE.binwrite(new_content.encode('ISO-8859-1'))
puts(pruned.positive? ? "✎ journal_entries.TXT: pruned #{pruned} future row(s) | #{message}" : message)
