require_relative 'stub_loader'
# moves.dat: confirm full battle fields on a damaging move
m = StubLoader.load_file(File.join(__dir__, '..', '..', 'Data', 'moves.dat'))
eq = m[:EARTHQUAKE]
puts "== EARTHQUAKE fields =="
eq.instance_variables.sort.each { |iv| puts "  #{iv} = #{eq.instance_variable_get(iv).inspect[0,80]}" }

# how many DISTINCT function_codes exist total, and among a sample of competitive moves
codes = {}
m.each { |k,v| next unless k.is_a?(Symbol); c = v.instance_variable_get(:@function_code); codes[c] = (codes[c]||0)+1 }
puts "\n== function_code coverage =="
puts "distinct function codes across #{m.count{|k,_|k.is_a?(Symbol)}} moves: #{codes.size}"

sample = %i[EARTHQUAKE DRACOMETEOR DRAGONDANCE CALMMIND SWORDSDANCE ROOST TOXIC KNOCKOFF SCALD THUNDER HURRICANE FIERYDANCE BODYSLAM PROTECT STEALTHROCK U_TURN FACADE]
puts "\n== sample competitive moves (power/acc/pri/cat/type/eff%/code) =="
sample.each do |s|
  mv = m[s] || m[s.to_s.sub('_','').to_sym]
  next puts "  #{s}: (not found under that id)" unless mv
  g = ->(i){ mv.instance_variable_get(i) }
  puts "  #{g.(:@id)}: pow #{g.(:@base_damage)} acc #{g.(:@accuracy)} pri #{g.(:@priority)} #{g.(:@category)} #{g.(:@type)} eff#{g.(:@effect_chance)} code=#{g.(:@function_code)}"
end

# types.dat: confirm we can get the effectiveness chart
begin
  t = StubLoader.load_file(File.join(__dir__, '..', '..', 'Data', 'types.dat'))
  puts "\n== types.dat =="
  puts "top class: #{t.class}, size #{t.size rescue '?'}"
  if t.is_a?(Array)
    t.each_with_index { |seg,i| puts "  seg#{i}: #{seg.class} #{(seg.is_a?(Array)||seg.is_a?(Hash)) ? "size #{seg.size}" : seg.inspect[0,60]}" }
  end
rescue => e
  puts "types.dat load note: #{e}"
end
