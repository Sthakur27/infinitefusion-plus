# Dump one PC box's full contents (decoded Head/Body fusion names + moves/ability/item/nature/stats/EVs).
# READ-ONLY.  ruby export_box.rb <save> <box_idx> <out.txt>
require_relative 'stub_loader'
require 'json'
SAVE, BOX, OUT = ARGV[0], ARGV[1].to_i, ARGV[2]
TABLE = JSON.parse(File.read(File.join(__dir__, 'species_table.json')))
def ivg(o, n) o.instance_variable_get(n) end

def species_name(pk, table)
  s = ivg(pk, :@species)
  if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
    head = table[$2]&.dig('name') || "##{$2}"
    body = table[$1]&.dig('name') || "##{$1}"
    "#{head}/#{body}"                       # Head/Body per fusion convention
  else
    (table.values.find { |r| r['id'].to_s == s.to_s } || {})['name'] || s.to_s
  end
end

save  = StubLoader.load_file(SAVE)
boxes = ivg(save[:storage_system], :@boxes)
box   = boxes[BOX] or abort "no box #{BOX}"
name  = ivg(box, :@name)
mons  = ivg(box, :@pokemon) || []
lines = ["=== BOX idx #{BOX} \"#{name}\" — #{mons.compact.length} mons ===\n"]
mons.each_with_index do |pk, si|
  next unless pk
  nn  = ivg(pk, :@name)
  ab  = ivg(pk, :@ability)
  it  = ivg(pk, :@item)
  nat = ivg(pk, :@nature)
  lvl = ivg(pk, :@level)
  mv  = (ivg(pk, :@moves) || []).map { |m| ivg(m, :@id) }.compact
  ev  = ivg(pk, :@ev)
  evs = (ev.respond_to?(:each) ? ev.select { |_, v| v.to_i > 0 }.map { |k, v| "#{k}:#{v}" }.join(' ') : '')
  lines << "slot #{si + 1}: #{species_name(pk, TABLE)}#{nn ? " \"#{nn}\"" : ''} L#{lvl} #{nat} #{ab} @#{it}"
  lines << "   Atk#{ivg(pk,:@attack)} Def#{ivg(pk,:@defense)} SpA#{ivg(pk,:@spatk)} SpD#{ivg(pk,:@spdef)} Spe#{ivg(pk,:@speed)} HP#{ivg(pk,:@totalhp)}"
  lines << "   moves: #{mv.join(', ')}"
  lines << "   EVs: #{evs}" unless evs.empty?
end
File.write(OUT, lines.join("\n") + "\n")
puts "wrote #{mons.compact.length} mons -> #{OUT}"
