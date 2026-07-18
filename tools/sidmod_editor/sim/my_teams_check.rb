# Validate all 3 of my teams build with the intended species/types (catch invalid
# species that silently resolve wrong, like EXCADRILL->Pikachu).
require_relative 'my_team'
SimEngine.boot
$DEBUG = false

def types(pk)
  (pk.types rescue [pk.type1, pk.type2].compact).uniq.map(&:to_s).join("/")
end

MY_TEAMS.each do |name, specs|
  puts "\n=== #{name} ==="
  bases = []
  specs.each do |s|
    bases << s[:head] << s[:body]
    # flag any base that isn't a real dex entry (would silently mis-resolve)
    [s[:head], s[:body]].each do |b|
      r = GameData::Species.get(b) rescue nil
      warn "  !! #{b} -> #{r ? "#{r.id}(dex #{r.id_number})" : 'MISSING'}" if r.nil? || r.id != b
    end
  end
  BuildTeam.team(specs).each do |pk|
    puts "  #{pk.speciesName.ljust(16)} [#{types(pk)}]  #{(pk.ability&.id rescue '?')}  S#{pk.speed} A#{pk.attack} C#{pk.spatk}"
  end
  dup = bases.tally.select { |_, c| c > 1 }.keys
  puts "  DUP BASES: #{dup.inspect}" unless dup.empty?
end
