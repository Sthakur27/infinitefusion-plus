# Convert the 6 deliverable teams -> an edit_save spec placing them in boxes 18/19/20
# (array idx 17/18/19), 2 teams per box, each mon nicknamed with its team. READ-ONLY (writes a spec).
#   ruby final_to_spec.rb <final_field.json> <out_spec.json>
require 'json'
FIELD = ARGV[0] or abort "usage: final_to_spec.rb <field.json> <out_spec.json>"
OUT   = ARGV[1] or abort "need out spec path"
ORDER = %w[OUBalance OURain OUSun OUSand Ubers1 Ubers2]   # box18: 0,1  box19: 2,3  box20: 4,5
field = JSON.parse(File.read(FIELD))
entries = []
ORDER.each_with_index do |name, t|
  team = field[name] or abort "field missing #{name}"
  box  = 17 + (t / 2)          # 17,17,18,18,19,19
  base = (t % 2) * 6           # 0 or 6
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
puts "wrote #{entries.length} mons (Box 18: #{ORDER[0]}/#{ORDER[1]}; Box 19: #{ORDER[2]}/#{ORDER[3]}; Box 20: #{ORDER[4]}/#{ORDER[5]}) -> #{OUT}"
