# Attempt to boot the real engine headless by eval'ing Data/Scripts in order
# (mirrors Main's load_scripts_from_folder). Reports how far it got + first error.
# Run with CWD = game root (C:\Games\InfiniteFusion).
require_relative 'shim'
require_relative '../stub_loader'
require 'zlib'

# The real boot evals the "GameSettings" bootstrap entry (from Scripts.rxdata)
# before Main runs the folder loader. Do the same.
_scripts = StubLoader.load_file("Data/Scripts.rxdata")
_gs = _scripts.find { |e| e[1].to_s == 'GameSettings' }
eval(Zlib::Inflate.inflate(_gs[2]), TOPLEVEL_BINDING, 'GameSettings') if _gs

$loaded = 0
$failures = []
def load_scripts_from_folder(path)
  files = []; folders = []
  ignored = ['.', '..', '.git', '.idea', '.gitignore']
  Dir.foreach(path) do |f|
    next if ignored.include?(f)
    File.directory?(path + "/" + f) ? folders.push(f) : files.push(f)
  end
  files.sort!
  files.each do |f|
    full = path + "/" + f
    code = File.read(full)
    begin
      eval(code, TOPLEVEL_BINDING, f)
      $loaded += 1
    rescue Exception => e
      $failures << [full, "#{e.class}: #{e.message.lines.first.to_s.strip}"]
    end
  end
  folders.sort!
  folders.each { |folder| load_scripts_from_folder(path + "/" + folder) }
end

$VERBOSE = nil   # silence "already initialized constant" warnings
load_scripts_from_folder("Data/Scripts")
puts "\n==== boot summary: #{$loaded} OK, #{$failures.length} failed ===="
# group failures by top-level folder
by_folder = Hash.new(0)
$failures.each { |f, _| by_folder[f.split('/')[2]] += 1 }
puts "failures by folder:"
by_folder.sort.each { |k, v| puts "  #{k}: #{v}" }
puts "\nfailures:"
$failures.each { |f, m| puts "  #{f.sub('Data/Scripts/', '')}\n      #{m}" }

# ---- prove the API is live ----
puts "\n==== API PROBE ===="
def probe(label)
  print "  #{label}: "
  puts(yield.inspect[0, 90])
rescue Exception => e
  puts "FAIL #{e.class}: #{e.message.lines.first.to_s.strip[0, 80]}"
end

# GameData is normally populated by Game.load -> GameData.load_all (which Main triggers).
probe("GameData.load_all") { GameData.load_all; "done" }

probe("GameData::Move EARTHQUAKE power") { GameData::Move.get(:EARTHQUAKE).base_damage }
probe("GameData::Species BULBASAUR")     { GameData::Species.get(:BULBASAUR).real_name }
probe("GameData::Type count")            { GameData::Type.count }
probe("PokeBattle_Battle defined")       { defined?(PokeBattle_Battle) ? "yes" : "no" }
probe("PokeBattle_Battler defined")      { defined?(PokeBattle_Battler) ? "yes" : "no" }
probe("PokeBattle_Move#pbCalcDamage")    { PokeBattle_Move.method_defined?(:pbCalcDamage) ? "yes" : "no" }
probe("AI class defined")                { defined?(PokeBattle_AI) ? "yes" : "no" }
probe("Pokemon.new works")               { Pokemon.new(:PIKACHU, 50).name }
