#!/usr/bin/env ruby
# frozen_string_literal: true

# Extrapole le dossier TELEPAC d'une campagne vers une autre.
# Duplique telepac/<FROM>/statement.xml en telepac/<TO>/statement.xml
# en bumpant uniquement l'attribut `fichier-xsd` à l'année cible — le reste
# du contenu reste identique (parcellaire, cultures, géométries), conformément
# au choix "pas de rotation" (brainstorm Q-A).
#
# Lit depuis demo-data/demo/telepac/<FROM>/ et écrit dans demo-data/demo/telepac/<TO>/.
# Idempotent : la sortie est stable à FROM/TO/SEED donnés.
#
# Usage :
#   FROM=2023 TO=2024 ruby bin/extrapolate_telepac.rb
#   FROM=2023 TO=2025 ruby bin/extrapolate_telepac.rb

require 'fileutils'
require 'pathname'

FROM = ENV.fetch('FROM', '2023').to_s
TO = ENV.fetch('TO', nil)
abort 'TO env var is required' if TO.nil? || TO.empty?

ROOT = Pathname.new(__dir__).parent.join('demo', 'telepac')
src_dir = ROOT.join(FROM)
dst_dir = ROOT.join(TO)
src_file = src_dir.join('statement.xml')
abort "Missing source: #{src_file}" unless src_file.exist?

FileUtils.mkdir_p(dst_dir)

# TELEPAC XML est en ISO-8859-1 — on lit/écrit en binaire pour préserver l'encodage.
content = src_file.binread
bumped = content.sub(
  /(fichier-xsd=")Echanges-producteur-export-#{Regexp.escape(FROM)}(-V\d+")/,
  "\\1Echanges-producteur-export-#{TO}\\2"
)

if bumped == content
  warn "Warning: fichier-xsd attribute for #{FROM} not found in #{src_file} — writing as-is."
end

dst_file = dst_dir.join('statement.xml')
dst_file.binwrite(bumped)
puts "✔ telepac/#{FROM}/statement.xml → telepac/#{TO}/statement.xml (#{bumped.bytesize} bytes)"
