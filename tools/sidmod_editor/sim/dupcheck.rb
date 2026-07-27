require "json"
f = JSON.parse(File.read(File.join("C:/Games/InfiniteFusion/tools/sidmod_editor/sim","reports","final","field_specs.json")))
%w[OUBalance OURain OUSun OUSand Ubers1 Ubers2].each do |t|
  sp = f[t].flat_map { |m| [m["head"], m["body"], m["species"]].compact }
  dups = sp.group_by { |x| x }.select { |_, v| v.length > 1 }.keys
  puts "#{t.ljust(10)} #{dups.empty? ? 'CLEAN (6 distinct species)' : 'DUP: '+dups.join(',')}"
end
