# Convert a sim field_specs.json (10 teams) into an edit_save spec that REPLACES the
# 60 slots of two "live" boxes (5 teams each). Deterministic slot layout so each
# iteration overwrites the SAME live copy. Each mon is nicknamed with its team so the
# boxes are readable in-game.  READ-ONLY (just writes a spec.json).
#   ruby field_to_spec.rb <field_specs.json> <out_spec.json> [boxA_idx=23] [boxB_idx=24]
require 'json'

FIELD = ARGV[0] or abort "usage: field_to_spec.rb <field_specs.json> <out_spec.json> [boxA] [boxB]"
OUT   = ARGV[1] or abort "need out spec path"
BOXA  = (ARGV[2] || 23).to_i      # in-game "Box 24"
BOXB  = (ARGV[3] || 24).to_i      # in-game "Box 25"
ORDER = %w[Sun Rain Sand Squads Box15A Box15B Box15C Momentum Overload Bunker]

field = JSON.parse(File.read(FIELD))
entries = []
ORDER.each_with_index do |name, t|
  team = field[name] or abort "field_specs missing team '#{name}'"
  box  = t < 5 ? BOXA : BOXB
  base = (t % 5) * 6                 # 6 slots per team
  team.first(6).each_with_index do |m, j|
    e = { "mode" => "replace", "box" => box, "slot" => base + j,
          "level" => 100, "nickname" => name,     # always L100 - no level bias
          "nature" => m["nature"], "ability" => m["ability"], "item" => m["item"],
          "moves" => (m["moves"] || []), "evs" => (m["evs"] || {}) }
    if m["head"] && m["body"]
      e["head"] = m["head"]; e["body"] = m["body"]
    else
      e["species"] = m["species"] || m["head"]
    end
    entries << e
  end
end
File.write(OUT, JSON.generate({ "pokemon" => entries }))
puts "wrote #{entries.length} entries (#{ORDER.first(5).join('/')} -> box #{BOXA + 1}; #{ORDER.last(5).join('/')} -> box #{BOXB + 1}) -> #{OUT}"
