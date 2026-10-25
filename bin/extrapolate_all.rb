#!/usr/bin/env ruby
# frozen_string_literal: true

# Orchestrateur — rejoue tous les runners pour couvrir la plage FROM_TELEPAC → TO.
# Pour TELEPAC : duplique 2023/statement.xml vers chaque année manquante.
# Pour les autres sources : les runners trouvent eux-mêmes l'année max.
#
# Usage :
#   TO=2026 ruby bin/extrapolate_all.rb           # couvre 2024,2025,2026
#   FROM_TELEPAC=2023 TO=2026 ruby bin/extrapolate_all.rb

require 'pathname'

TO = (ENV['TO'] || '').to_i
abort 'TO env var is required (e.g. TO=2026)' if TO.zero?

FROM_TELEPAC = (ENV['FROM_TELEPAC'] || '2023').to_i
BIN = Pathname.new(__dir__)

def run(script, env)
  env_str = env.map { |k, v| "#{k}=#{v}" }.join(' ')
  puts "\n→ #{env_str} ruby bin/#{script}"
  system(env.transform_keys(&:to_s).transform_values(&:to_s), 'ruby', BIN.join(script).to_s) || abort("Failed: #{script}")
end

# 1) TELEPAC : une sortie par année manquante entre FROM_TELEPAC+1 et TO.
((FROM_TELEPAC + 1)..TO).each do |year|
  src = Pathname.new(__dir__).parent.join('demo', 'telepac', FROM_TELEPAC.to_s, 'statement.xml')
  dst = Pathname.new(__dir__).parent.join('demo', 'telepac', year.to_s, 'statement.xml')
  if dst.exist?
    puts "⊘ telepac/#{year}/statement.xml already present"
  elsif !src.exist?
    warn "⚠ telepac/#{FROM_TELEPAC}/statement.xml missing — skipping telepac/#{year}"
  else
    run('extrapolate_telepac.rb', FROM: FROM_TELEPAC, TO: year)
  end
end

# 2) Opérations alamano : une passe par année cible (année max → TO).
((FROM_TELEPAC + 1)..TO).each do |year|
  run('extrapolate_operations.rb', TO: year)
end

# 3) Compta Istea : idem.
((FROM_TELEPAC + 1)..TO).each do |year|
  run('extrapolate_compta.rb', TO: year)
end

# 4) Cheptel : stub no-op.
run('extrapolate_cheptel.rb', {})

puts "\n✔ Extrapolation complete up to #{TO}"
