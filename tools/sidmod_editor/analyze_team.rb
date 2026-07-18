# Full competitive profile of party + a chosen box (types computed via fusion rule).
#   ruby analyze_team.rb <save> <boxIndex>
require_relative 'stub_loader'
require 'json'
SAVE = ARGV[0]; BOX = ARGV[1].to_i
TABLE = JSON.parse(File.read(File.join(__dir__, 'species_table.json')))
NB = 501
def ivg(o,n) o.instance_variable_get(n) end
BY_ID = {}; TABLE.each { |d,r| BY_ID[r['id']] = r.merge('dex'=>d.to_i) }

def rec_for(dex) TABLE[dex.to_s] end

def types_of(pk)
  s = ivg(pk, :@species)
  if s.is_a?(Symbol) && s.to_s =~ /\AB(\d+)H(\d+)\z/
    b=$1.to_i; h=$2.to_i
    hb=rec_for(h); bb=rec_for(b)
    return ["?","?","#{h}/#{b}"] unless hb && bb
    t1 = (hb['type1']=='NORMAL' && hb['type2']=='FLYING') ? hb['type2'] : hb['type1']
    t2 = (bb['type2']==t1 ? bb['type1'] : bb['type2'])
    name = "#{hb['name']}/#{bb['name']}"
    ty = (t2.nil? || t2==t1) ? t1 : "#{t1}/#{t2}"
    [name, ty]
  else
    r = BY_ID[s.to_s]
    return [s.to_s, "?"] unless r
    ty = (r['type2'].nil? || r['type2']==r['type1']) ? r['type1'] : "#{r['type1']}/#{r['type2']}"
    [r['name'], ty]
  end
end

def profile(pk, idx)
  return "  #{idx}. (empty)" if pk.nil?
  name, ty = types_of(pk)
  nn = ivg(pk,:@name) ? "\"#{ivg(pk,:@name)}\" " : ""
  ev = (ivg(pk,:@ev)||{}).select{|k,v| v.to_i>0}.map{|k,v| "#{v} #{k.to_s.sub('SPECIAL_','Sp')[0,3]}"}.join('/')
  mv = (ivg(pk,:@moves)||[]).map{|m| ivg(m,:@id).to_s.capitalize}.join(', ')
  st = "H#{ivg(pk,:@totalhp)} A#{ivg(pk,:@attack)} B#{ivg(pk,:@defense)} C#{ivg(pk,:@spatk)} D#{ivg(pk,:@spdef)} S#{ivg(pk,:@speed)}"
  out =  "  #{idx}. #{nn}#{name}  [#{ty}]  L#{ivg(pk,:@level)}\n"
  out << "       #{ivg(pk,:@ability)} | @#{ivg(pk,:@item)} | #{ivg(pk,:@nature)} | #{ev}\n"
  out << "       #{mv}\n"
  out << "       #{st}"
  out
end

save = StubLoader.load_file(SAVE)
puts "===== PARTY ====="
(ivg(save[:player], :@party)||[]).each_with_index { |pk,i| puts profile(pk, i+1) }
box = ivg(save[:storage_system], :@boxes)[BOX]
puts "\n===== BOX #{BOX+1} \"#{ivg(box,:@name)}\" ====="
(ivg(box, :@pokemon)||[]).each_with_index { |pk,i| puts profile(pk, i+1) if pk }
