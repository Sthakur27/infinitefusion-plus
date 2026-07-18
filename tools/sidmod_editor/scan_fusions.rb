# Find all fusions of a given type combo, ranked by fused BST, with ability pool.
#   ruby scan_fusions.rb <TYPE1> <TYPE2>
require_relative 'pokemath'
require 'json'
require 'set'
T1 = ARGV[0].upcase; T2 = ARGV[1].upcase
TABLE = JSON.parse(File.read(File.join(__dir__, 'species_table.json')))

LEGEND = %w[ARTICUNO ZAPDOS MOLTRES MEWTWO MEW RAIKOU ENTEI SUICUNE LUGIA HOOH HO_OH CELEBI
  REGIROCK REGICE REGISTEEL LATIAS LATIOS KYOGRE GROUDON RAYQUAZA JIRACHI DEOXYS DIALGA PALKIA
  GIRATINA HEATRAN CRESSELIA DARKRAI ARCEUS REGIGIGAS PHIONE MANAPHY SHAYMIN VICTINI].to_set

def fused_type(hb, bb)
  t1 = (hb['type1']=='NORMAL' && hb['type2']=='FLYING') ? hb['type2'] : hb['type1']
  t2 = (bb['type2']==t1 ? bb['type1'] : bb['type2'])
  [t1, t2]
end

rows = []
base = TABLE.select { |d,_| d.to_i.between?(1, 501) }
base.each do |hd, hb|
  next unless hb['type1'] == T1 || (hb['type1']=='NORMAL' && hb['type2']=='FLYING' && hb['type2']==T1)
  base.each do |bd, bb|
    # body must supply T2 as its secondary
    next unless bb['type2'] == T2 || (bb['type2'].nil? && bb['type1'] == T2)
    t1, t2 = fused_type(hb, bb)
    next unless t1 == T1 && t2 == T2
    fs = PokeMath.fused_base_stats(hb['base_stats'], bb['base_stats'])
    bst = fs.values.sum
    abils = ((bb['abilities']||[]) + (hb['abilities']||[]) + (bb['hidden']||[]) + (hb['hidden']||[])).uniq
    rows << {
      name: "#{hb['name']}/#{bb['name']}", head: hb['name'], body: bb['name'],
      bst: bst, atk: fs['ATTACK'], spa: fs['SPECIAL_ATTACK'], spe: fs['SPEED'],
      hp: fs['HP'], defe: fs['DEFENSE'], spd: fs['SPECIAL_DEFENSE'],
      abils: abils, leg: (LEGEND.include?(hd_up=hb['id']) || LEGEND.include?(bb['id']))
    }
  end
end
rows.sort_by! { |r| -r[:bst] }
rows.reject! { |r| r[:leg] } if ARGV[2] == 'nolegend'
puts "#{T1}/#{T2} fusions: #{rows.length} combos. Top 15 by fused BST:"
rows.first(15).each do |r|
  sand = (r[:abils] & %w[SANDRUSH SANDFORCE SANDVEIL]).join(',')
  tag = r[:leg] ? " [LEGEND]" : ""
  puts sprintf("  %-26s BST %d  (Atk %d Spe %d SpA %d / HP %d Def %d SpD %d)%s",
               r[:name], r[:bst], r[:atk], r[:spe], r[:spa], r[:hp], r[:defe], r[:spd], tag)
  puts "        abilities: #{r[:abils].join(', ')}#{sand.empty? ? '' : "   <== SAND: #{sand}"}"
end
