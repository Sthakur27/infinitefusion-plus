# Extract the hardest Elite 4 + Champions from the AI trainer data and rebuild them at L100
# (faithful: keep species/moves/ability/item/nature/EVs/IVs, only bump level to 100). Writes
# reports/gauntlet/field_specs.json — a REAL, non-self-referential competitive benchmark meta.
require_relative 'build_team'
require 'json'; require 'fileutils'
SimEngine.boot; $DEBUG = false
OUT = File.join(__dir__, 'reports', 'gauntlet'); FileUtils.mkdir_p(OUT)

# [display_name, registry, trainer_id, trainer_name, version]  — highest = hardest
GAUNTLET = [
  ["Lorelei", GameData::TrainerExpert, :ELITEFOUR_Lorelei, "Lorelei", 2],
  ["Bruno",   GameData::TrainerExpert, :ELITEFOUR_Bruno,   "Bruno",   2],
  ["Agatha",  GameData::TrainerExpert, :ELITEFOUR_Agatha,  "Agatha",  2],
  ["Lance",   GameData::TrainerExpert, :ELITEFOUR_Lance,   "Lance",   4],
  ["BlueExpert", GameData::TrainerExpert, :RIVAL1,   "Blue", 24],
  ["BlueRemix",  GameData::TrainerModern, :CHAMPION, "Blue", 8],
]

def decode(sp)                              # :B<body>H<head> -> [head_sym, body_sym] or [nil, mono]
  if sp.to_s =~ /\AB(\d+)H(\d+)\z/
    head = (GameData::Species.get($2.to_i).id rescue nil)
    body = (GameData::Species.get($1.to_i).id rescue nil)
    [head, body]
  else
    [nil, sp]
  end
end

def evs_str(ev)
  h = {}
  (ev || {}).each { |k, v| h[k.to_s.upcase] = v.to_i if v.to_i > 0 }
  h
end

field = {}
GAUNTLET.each do |name, reg, tid, tname, ver|
  t = (reg.get(tid, tname, ver) rescue nil)
  unless t
    warn "!! missing #{name} (#{tid} #{tname} v#{ver})"; next
  end
  party = (t.pokemon rescue []) || []
  team = party.map do |p|
    head, body = decode(p[:species])
    e = { "ability" => (p[:ability]&.to_s), "item" => (p[:item]&.to_s), "nature" => (p[:nature]&.to_s || "HARDY"),
          "moves" => (p[:moves] || []).map(&:to_s), "evs" => evs_str(p[:ev]), "level" => 100 }
    if head && body then e["head"] = head.to_s; e["body"] = body.to_s else e["species"] = body.to_s end
    e.reject { |_, v| v.nil? }
  end
  field[name] = team
  puts "#{name.ljust(11)} (#{tname} v#{ver}): #{team.length} mons — #{team.map { |m| m['head'] ? "#{m['head']}/#{m['body']}" : m['species'] }.join(', ')}"
end

File.write(File.join(OUT, 'field_specs.json'), JSON.generate(field))

# validate every mon builds at L100
require_relative 'editor'
bad = []
field.each do |name, team|
  team.each_with_index do |m, i|
    s = Editor.normalize(m)
    begin
      pk = BuildTeam.mon(s)
      badmv = (s[:moves] || []).reject { |mv| GameData::Move.exists?(mv) rescue false }
      bad << "#{name}[#{i}] badmoves #{badmv.join(',')}" unless badmv.empty?
    rescue => e
      bad << "#{name}[#{i}] BUILD FAIL #{s[:head]}/#{s[:body]}#{s[:species]} #{e.class}"
    end
  end
end
puts "\n" + (bad.empty? ? "ALL GAUNTLET MONS BUILD OK @L100" : "ISSUES:\n  " + bad.join("\n  "))
puts "wrote reports/gauntlet/field_specs.json (#{field.size} opponents)"
