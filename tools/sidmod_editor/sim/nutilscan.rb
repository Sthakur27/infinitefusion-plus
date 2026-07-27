require_relative 'nstore'
require_relative 'nbattle'
require_relative 'editor'
NativeSim.boot!
CANDS = %w[SKARMORY CORVIKNIGHT FORRETRESS TENTACRUEL STARMIE BLASTOISE EMPOLEON MANDIBUZZ
           ZAPDOS ARTICUNO MOLTRES SUICUNE REGISTEEL REGIROCK SCIZOR FERROTHORN TOXAPEX
           GOODRA HIPPOWDON GLISCOR SKARMORY DONPHAN CLAYDOL BRONZONG ESPEON UMBREON
           MEW CELEBI LATIAS ROTOM HYDREIGON DRAGONITE SLOWBRO QUAGSIRE MILOTIC
           AMOONGUSS TANGROWTH VAPOREON JELLICENT AVALUGG CRUSTLE ARMALDO CRADILY
           WHIMSICOTT SYLVEON CLEFABLE BLISSEY CHANSEY DUSCLOPS COFAGRIGUS MIMIKYU
           EXCADRILL SANDSLASH TORKOAL NINETALES POLITOED PELIPPER TYRANITAR]
UT = { defog: :DEFOG, spin: :RAPIDSPIN, sr: :STEALTHROCK, spikes: :SPIKES, tspikes: :TOXICSPIKES,
       roost: :ROOST, recover: :RECOVER, wish: :WISH, softboiled: :SOFTBOILED, rest: :REST,
       whirlwind: :WHIRLWIND, knockoff: :KNOCKOFF, uturn: :UTURN, voltswitch: :VOLTSWITCH }
def mp(sym)
  sp = (GameData::Species.get(sym) rescue nil) or return nil
  return nil unless sp.id == sym
  s = []
  (sp.moves rescue []).each { |m| s << (m.is_a?(Array) ? m[1] : m) }
  (sp.tutor_moves rescue []).each { |m| s << m }
  (sp.egg_moves rescue []).each { |m| s << m }
  [sp, s.compact.map { |m| m.to_s.to_sym }.uniq]
end
puts "%-14s %-7s %-22s %s" % %w[species exists types utility]
CANDS.uniq.each do |c|
  sym = c.to_sym
  r = mp(sym)
  if !r
    puts "%-14s %-7s %s" % [c, 'NO', '(absent from this dex / resolves elsewhere)']
    next
  end
  sp, pool = r
  tools = UT.select { |_k, mv| pool.include?(mv) }.keys
  ab = (sp.abilities rescue []).map { |a| a.to_s }.first(3).join(',') rescue ''
  puts "%-14s %-7s %-22s %s  [ab: %s]" % [c, 'yes', "#{sp.types.join('/')}",
    tools.join(' '), ab]
end
