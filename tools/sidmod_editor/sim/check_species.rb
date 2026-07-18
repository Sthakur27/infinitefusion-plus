# Verify each species NAME resolves to itself (not a silent fallback like EXCADRILL->Pikachu).
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
names = %w[DIALGA ESPEON METAGROSS KYOGRE TOXAPEX GASTRODON QUAGSIRE DRAGONITE GYARADOS
           SUICUNE TOGEKISS FERROTHORN RHYPERIOR SLOWBRO TANGROWTH EMPOLEON STEELIX]
names.each do |n|
  sym = n.to_sym
  r = (GameData::Species.get(sym) rescue nil)
  ok = r && r.id == sym
  dex = (r.respond_to?(:id_number) ? r.id_number : (r.respond_to?(:number) ? r.number : '?')) rescue '?'
  puts "#{ok ? 'OK  ' : 'BAD '} #{n.ljust(11)} -> id=#{r ? r.id : 'nil'}  dex=#{dex}  types=#{r ? (r.types rescue [r.type1, r.type2]).compact.join('/') : '-'}"
end
