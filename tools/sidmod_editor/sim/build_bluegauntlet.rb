# Extract Blue's champion fights (Classic/Remix/Expert) + Cynthia & Gold kaizo (Expert) at L100.
require_relative 'build_team'; require_relative 'editor'
require 'json'; require 'fileutils'
SimEngine.boot; $DEBUG = false
OUT = File.join(__dir__, 'reports', 'blue_gauntlet'); FileUtils.mkdir_p(OUT)

SET = [
  ["BlueClassic",  GameData::Trainer,       :CHAMPION,             "Blue",    8],
  ["BlueRemix",    GameData::TrainerModern,  :CHAMPION,             "Blue",    8],
  ["BlueExpert",   GameData::TrainerExpert,  :RIVAL1,               "Blue",    24],
  ["CynthiaKaizo", GameData::TrainerExpert,  :CHAMPION_Sinnoh,      "Cynthia", 0],
  ["GoldKaizo",    GameData::TrainerExpert,  :POKEMONTRAINER_Gold,  "Gold",    0],
  ["CynthiaRemix", GameData::TrainerModern,  :CHAMPION_Sinnoh,      "Cynthia", 0],  # Spiritomb/Sableye dual-screens lead
  ["GoldRemix",    GameData::TrainerModern,  :POKEMONTRAINER_Gold,  "Gold",    0],
  ["RemixLance",   GameData::TrainerModern,  :ELITEFOUR_Lance,      "Lance",   4],  # Slurpuff/Dragonite BellyDrum/Unburden lead
]

def decode(sp)
  if sp.to_s =~ /\AB(\d+)H(\d+)\z/
    [(GameData::Species.get($2.to_i).id rescue nil), (GameData::Species.get($1.to_i).id rescue nil)]
  else [nil, sp] end
end
def evs_str(ev); h={}; (ev||{}).each{|k,v| h[k.to_s.upcase]=v.to_i if v.to_i>0}; h; end

field = {}
SET.each do |name, reg, tid, tname, ver|
  t = (reg.get(tid, tname, ver) rescue nil)
  (warn "!! missing #{name}"; next) unless t
  team = ((t.pokemon rescue []) || []).map do |p|
    head, body = decode(p[:species])
    e = { "ability"=>(p[:ability]&.to_s), "item"=>(p[:item]&.to_s), "nature"=>(p[:nature]&.to_s||"HARDY"),
          "moves"=>(p[:moves]||[]).map(&:to_s), "evs"=>evs_str(p[:ev]), "level"=>100 }
    if head && body then e["head"]=head.to_s; e["body"]=body.to_s else e["species"]=body.to_s end
    e.reject { |_, v| v.nil? }
  end
  field[name] = team
  puts "#{name.ljust(13)}: #{team.map{|m| m['head'] ? "#{m['head']}/#{m['body']}" : m['species']}.join(', ')}" rescue puts(name)
end
File.write(File.join(OUT, 'field_specs.json'), JSON.generate(field))

bad = []
field.each { |name, team| team.each_with_index { |m,i|
  begin; BuildTeam.mon(Editor.normalize(m)); rescue => e; bad << "#{name}[#{i}] FAIL #{e.class}"; end } }
puts(bad.empty? ? "ALL BUILD OK @L100 (#{field.size} teams)" : "ISSUES:\n  "+bad.join("\n  "))
