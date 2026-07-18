require_relative 'stub_loader'
save = StubLoader.load_file(ARGV[0])
party = save[:player].instance_variable_get(:@party)

def dump(pk, label)
  puts "===== #{label} : #{pk.class} ====="
  pk.instance_variables.sort.each do |iv|
    v = pk.instance_variable_get(iv)
    s = case v
        when Array then "Array(#{v.length}) " + v.first(6).map { |e| e.is_a?(Object) && e.instance_variables.any? ? "#{e.class}#{e.instance_variables.map{|i|"#{i}=#{e.instance_variable_get(i).inspect}"}.join(",")}" : e.inspect }.join(" | ")
        when Hash then v.inspect
        else v.inspect
        end
  puts sprintf("  %-26s = %s", iv, s[0, 160])
  end
end

dump(party[0], "PARTY[0] (fusion Tyranitar/Slaking)")
dump(party[3], "PARTY[3] (Blissey/Shuckle)")
