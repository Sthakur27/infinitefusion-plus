require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
# candidate rain-team species (Swift Swim abusers, Water breakers, Groucor answers)
%w[KABUTOPS OMASTAR KINGLER LUDICOLO SEISMITOAD BARRASKEWDA QWILFISH POLIWRATH GOLDUCK
   CLOYSTER SHARPEDO CRAWDAUNT FLOATZEL SAMUROTT KABUTO OMANYTE PELIPPER MANTINE
   BEARTIC WALREIN LAPRAS AZUMARILL KINGDRA POLITOED WHIMSICOTT].each do |n|
  sym = n.to_sym
  r = (GameData::Species.get(sym) rescue nil)
  ok = r && r.id == sym
  ab = r ? (r.abilities rescue []).flatten.compact : []
  ss = ab.map(&:to_s).include?('SWIFTSWIM')
  puts "#{ok ? 'OK ' : 'BAD'} #{n.ljust(12)} #{ok ? "types=#{(r.types rescue []).join('/')} abilities=#{ab.join(',')}" : "-> #{r ? r.id : 'nil'}"}"
end
