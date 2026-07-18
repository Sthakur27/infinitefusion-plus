# Read-only: dump party + all boxes from a save to JSON (stdout + pc_dump.json).
#   ruby read_save.rb <savefile> [species_table.json]
require_relative 'stub_loader'
require 'json'

SAVE = ARGV[0]
TABLE = JSON.parse(File.read(ARGV[1] || File.join(__dir__, 'species_table.json')))
NB = 501

def iv(o, name) o.instance_variable_get(name) end

def species_display(sym_or_int)
  s = sym_or_int
  body = head = nil
  if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
    body = $1.to_i; head = $2.to_i
  elsif s.is_a?(Integer) && s > NB
    body = s / NB; head = s % NB
  end
  if body && head
    bn = TABLE[body.to_s]&.dig('name') || "##{body}"
    hn = TABLE[head.to_s]&.dig('name') || "##{head}"
    { "fusion" => true, "display" => "#{hn}/#{bn}", "head" => hn, "body" => bn, "raw" => s.to_s }
  else
    # base species: s may be a symbol id; find its name by matching table id
    name = nil
    TABLE.each_value { |r| (name = r['name']; break) if r['id'] == s.to_s }
    { "fusion" => false, "display" => name || s.to_s, "raw" => s.to_s }
  end
end

def mon(pk)
  return nil if pk.nil?
  moves = (iv(pk, :@moves) || []).map { |m| iv(m, :@id).to_s }
  sd = species_display(iv(pk, :@species))
  {
    "nickname" => iv(pk, :@name),
    "species"  => sd["display"],
    "fusion"   => sd["fusion"],
    "head"     => sd["head"],
    "body"     => sd["body"],
    "level"    => iv(pk, :@level),
    "exp"      => iv(pk, :@exp),
    "nature"   => iv(pk, :@nature)&.to_s,
    "ability"  => iv(pk, :@ability)&.to_s,
    "ability_index" => iv(pk, :@ability_index),
    "item"     => iv(pk, :@item)&.to_s,
    "moves"    => moves,
    "ivs"      => iv(pk, :@iv),
    "evs"      => iv(pk, :@ev),
    "shiny"    => iv(pk, :@shiny),
    "gender"   => iv(pk, :@gender),
    "totalhp"  => iv(pk, :@totalhp),
    "stats"    => {
      "atk" => iv(pk, :@attack), "def" => iv(pk, :@defense),
      "spa" => iv(pk, :@spatk),  "spd" => iv(pk, :@spdef), "spe" => iv(pk, :@speed)
    }
  }
end

save = StubLoader.load_file(SAVE)
player  = save[:player]
storage = save[:storage_system]

party = (iv(player, :@party) || []).map { |pk| mon(pk) }
boxes = []
box_arr = iv(storage, :@boxes) || []
box_arr.each_with_index do |box, bi|
  next if box.nil?
  pkmn = iv(box, :@pokemon) || []
  filled = pkmn.compact.length
  boxes << {
    "index"   => bi,
    "display" => bi + 1,
    "name"    => iv(box, :@name),
    "capacity"=> pkmn.length,
    "filled"  => filled,
    "pokemon" => pkmn.map { |pk| mon(pk) }   # nil = empty slot
  }
end

out = { "party" => party, "boxes" => boxes,
        "trainer" => { "name" => iv(player, :@name), "id" => iv(player, :@id) } }
File.write(File.join(__dir__, 'pc_dump.json'), JSON.pretty_generate(out))

# Compact human summary to stdout
def line(pk)
  return nil unless pk
  nn = pk["nickname"] ? "\"#{pk["nickname"]}\" " : ""
  sh = pk["shiny"] ? " *shiny*" : ""
  "#{nn}#{pk["species"]} L#{pk["level"]}#{sh}"
end
puts "Trainer: #{out["trainer"]["name"]}  (party #{party.compact.length}/6)"
puts "PARTY:"
party.each_with_index { |pk, i| puts "  #{i+1}. #{line(pk)}" if pk }
total = boxes.sum { |b| b["filled"] }
nonempty = boxes.select { |b| b["filled"] > 0 }
puts "\nBOXES: #{nonempty.length} non-empty, #{total} mons total, #{boxes.length} boxes"
boxes.each do |b|
  tag = b["filled"] == 0 ? "(empty)" : "#{b["filled"]}/#{b["capacity"]}"
  mons = b["pokemon"].compact.map { |pk| line(pk) }
  puts "  Box #{b["display"]} \"#{b["name"]}\" #{tag}"
  mons.each { |m| puts "      - #{m}" } unless mons.empty?
end

