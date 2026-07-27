# READ-ONLY. Dump every fusion in a save (party + all boxes) and flag which have no custom sprite.
require_relative 'C:/Games/InfiniteFusion/tools/sidmod_editor/stub_loader'
require 'json'

SAVE  = ARGV[0]
TABLE = JSON.parse(File.read('C:/Games/InfiniteFusion/tools/sidmod_editor/species_table.json'))
def ivg(o, n) = o.instance_variable_get(n)

# sprite index: set of "head.body" strings that have a custom sprite
custom = {}
File.foreach('C:/Games/InfiniteFusion/Data/sprites/CUSTOM_SPRITES') do |l|
  if l.strip =~ /\A(\d+)\.(\d+)([a-z]*)\.png\z/
    (custom["#{$1}.#{$2}"] ||= []) << ($3.empty? ? 'main' : $3)
  end
end

rows = []
def scan(pk, where, slot, table, rows)
  return unless pk
  s = ivg(pk, :@species).to_s
  nick = ivg(pk, :@name)
  lvl  = ivg(pk, :@level)
  if s =~ /\AB(\d+)H(\d+)\z/
    body, head = $1, $2
    rows << { where: where, slot: slot, head: head.to_i, body: body.to_i,
              head_name: table[head]&.dig('name') || "##{head}",
              body_name: table[body]&.dig('name') || "##{body}",
              nick: nick, level: lvl, fusion: true }
  else
    rows << { where: where, slot: slot, fusion: false, nick: nick, level: lvl,
              head_name: s, body_name: nil }
  end
end

save = StubLoader.load_file(SAVE)

(ivg(save[:player], :@party) || []).each_with_index { |pk, i| scan(pk, 'PARTY', i + 1, TABLE, rows) } rescue nil
(save[:party] || []).each_with_index { |pk, i| scan(pk, 'PARTY', i + 1, TABLE, rows) } rescue nil

boxes = ivg(save[:storage_system], :@boxes)
boxes.each_with_index do |box, bi|
  bname = ivg(box, :@name).to_s.strip
  (ivg(box, :@pokemon) || []).each_with_index do |pk, si|
    scan(pk, "box#{bi} #{bname}", si + 1, TABLE, rows)
  end
end

fus = rows.select { |r| r[:fusion] }
missing = fus.reject { |r| custom.key?("#{r[:head]}.#{r[:body]}") }

puts "total mons scanned : #{rows.size}"
puts "fusions            : #{fus.size}  (unique pairs: #{fus.map { |r| [r[:head], r[:body]] }.uniq.size})"
puts "non-fusion/other   : #{rows.size - fus.size}"
puts "MISSING custom art : #{missing.size}  (unique: #{missing.map { |r| [r[:head], r[:body]] }.uniq.size})"
puts

seen = {}
missing.each do |r|
  key = "#{r[:head]}.#{r[:body]}"
  next if seen[key]
  seen[key] = true
  puts format('%-9s %-34s %-22s L%-4s %s', key,
              "#{r[:head_name]}/#{r[:body_name]}", r[:nick] || '', r[:level], r[:where])
end

File.write(File.join(__dir__, 'missing.json'), JSON.pretty_generate(
  missing.uniq { |r| [r[:head], r[:body]] }))
File.write(File.join(__dir__, 'all_fusions.json'), JSON.pretty_generate(fus))
