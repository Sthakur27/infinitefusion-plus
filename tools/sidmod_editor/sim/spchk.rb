require_relative "engine"
SimEngine.boot
$DEBUG=false
%i[EXCADRILL RHYPERIOR DONPHAN FLYGON KROOKODILE MAMOSWINE GLISCOR GOLEM].each do |s|
  ex = GameData::Species.exists?(s)
  dn = (GameData::Species.get(s).id_number rescue "?")
  t = ex ? (r=GameData::Species.get(s); "#{r.type1}/#{r.type2}") : "-"
  puts "#{s}: exists=#{ex} dex=#{dn} #{t}"
end
