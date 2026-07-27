# Per-team audit data: each mon's fusion stats/type/ability + BOTH parents' stats at the
# SAME nature, so the auditor can judge "does the fusion beat mono?".  Writes reports/audit/<team>.txt
require 'json'
require 'fileutils'
TAG = ARGV[0] || 'hf'
FIELD = JSON.parse(File.read(File.join(__dir__, 'reports', TAG, 'field_specs.json')))  # parse before boot
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
OUT = File.join(__dir__, 'reports', "#{TAG}_audit"); FileUtils.mkdir_p(OUT)

def stat_line(pk)
  types = (pk.types rescue [pk.type1, pk.type2]).compact.map(&:to_s).join('/')
  "#{types.ljust(14)} Atk#{pk.attack} Def#{pk.defense} SpA#{pk.spatk} SpD#{pk.spdef} Spe#{pk.speed} HP#{pk.totalhp}"
end

FIELD.each do |team, mons|
  lines = ["=== #{team} — fusion-vs-mono audit data ===\n"]
  mons.each_with_index do |m, i|
    spec = Editor.normalize(m)
    nat = spec[:nature]
    pk = BuildTeam.mon(spec)
    name = spec[:head] && spec[:body] ? "#{spec[:head]}/#{spec[:body]}" : (spec[:species] || spec[:head]).to_s
    lines << "SLOT #{i + 1}: #{name} @#{spec[:item]} [#{pk.ability&.id}] #{spec[:nature]}"
    lines << "  FUSION: #{stat_line(pk)}"
    lines << "  moves : #{(spec[:moves] || []).join('/')}"
    if spec[:head] && spec[:body]
      [spec[:head], spec[:body]].each do |par|
        begin
          mono = BuildTeam.mon({ species: par, nature: nat, level: 100 })
          lines << "  mono #{par.to_s.ljust(11)}: #{stat_line(mono)}"
        rescue => e
          lines << "  mono #{par}: (build fail #{e.class})"
        end
      end
    end
    lines << ""
  end
  File.write(File.join(OUT, "#{team}.txt"), lines.join("\n"))
end
puts "wrote audit data for #{FIELD.size} teams -> reports/audit/"
