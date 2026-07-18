require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
puts "-- species --"
%w[KYOGRE GROUDON RAYQUAZA ARCEUS DARKRAI DIALGA PALKIA GIRATINA MEWTWO GENESECT
   FERROTHORN SCIZOR TYRANITAR FORRETRESS KYUREM LATIAS LATIOS EXCADRILL HEATRAN
   DEOXYS LUGIA HOOH REumSHIRAM ZEKROM PALKIA GENGAR TENTACRUEL BLISSEY].uniq.each do |n|
  sym = n.to_sym
  ok = Editor.valid_species?(sym)
  r = (GameData::Species.get(sym) rescue nil)
  puts "#{ok ? 'OK ' : 'BAD'} #{n.ljust(11)} #{ok ? (r.types rescue []).join('/') : "-> #{r ? r.id : 'nil'}"}"
end
puts "-- moves --"
%w[DARKVOID SPACIALREND JUDGMENT EXTREMESPEED WATERSPOUT DRACOMETEOR NASTYPLOT
   SWORDSDANCE SPIKES LEECHSEED POWERWHIP DARKPULSE FOCUSBLAST BULLETPUNCH PURSUIT
   ROOSTKAPUTT DRAGONTAIL WILLOWISP SLEEPTALK FIREBLAST THUNDER ICEBEAM SURF].each do |m|
  puts "#{GameData::Move.exists?(m) ? 'OK ' : 'BAD'} #{m}"
end
puts "-- abilities --"
%w[DRIZZLE DROUGHT AIRLOCK MULTITYPE BADDREAMS PRESSURE TECHNICIAN IRONBARBS SANDRUSH SANDSTREAM].each do |a|
  puts "#{GameData::Ability.exists?(a) ? 'OK ' : 'BAD'} #{a}"
end
