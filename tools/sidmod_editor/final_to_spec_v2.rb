# Place the 6 v2 deliverable teams into the ONLY two empty boxes of File A: array idx 20
# ("Box 21") and idx 22 ("Box 23"), 3 teams per box. Preserves v1 (idx 17/18/19) and everything
# else. Reads the benchmarked v2 field but materializes ONLY the 6 fusion teams (not the controls).
#   ruby final_to_spec_v2.rb <field_v2.json> <out_spec.json>
require 'json'
FIELD = ARGV[0] or abort "usage: final_to_spec_v2.rb <field.json> <out_spec.json>"
OUT   = ARGV[1] or abort "need out spec path"
ORDER = %w[OUBalance OURain OUSun OUSand Ubers1 Ubers2]   # box20: 0,1,2  box22: 3,4,5
BOXES = [20, 22]                                          # empty array indices in File A
field = JSON.parse(File.read(FIELD))
entries = []
ORDER.each_with_index do |name, t|
  team = field[name] or abort "field missing #{name}"
  box  = BOXES[t / 3]         # first 3 teams -> idx20, next 3 -> idx22
  base = (t % 3) * 6          # 0, 6, 12 within the box
  team.first(6).each_with_index do |mon, j|
    e = { "mode"=>"replace", "box"=>box, "slot"=>base + j, "level"=>100, "nickname"=>name,
          "ability"=>mon["ability"], "item"=>mon["item"], "nature"=>mon["nature"],
          "moves"=>(mon["moves"] || []), "evs"=>(mon["evs"] || {}) }
    if mon["head"] && mon["body"]
      e["head"] = mon["head"]; e["body"] = mon["body"]
    else
      e["species"] = mon["species"] || mon["head"]
    end
    entries << e
  end
end
File.write(OUT, JSON.generate({ "pokemon" => entries }))
puts "wrote #{entries.length} mons"
puts "  Box 21 (idx 20): #{ORDER[0]}, #{ORDER[1]}, #{ORDER[2]}"
puts "  Box 23 (idx 22): #{ORDER[3]}, #{ORDER[4]}, #{ORDER[5]}"
