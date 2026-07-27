# Prove the REAL engine resolves the installed sprites — not just that the files exist.
# Boots Data/Scripts headless, then calls the game's own pbResolveBitmap on the exact
# path BattleSpriteLoader#check_for_local_sprite builds.
#
#   RUN FROM GAME ROOT:  ruby tools/sidmod_editor/sprites/verify_install.rb
require 'json'
# Read the worklist BEFORE booting: the engine's 003_HTTP_Utilities.rb replaces
# JSON.parse with an eval-based parser that chokes on plain JSON (RUNBOOK gotcha).
missing = JSON.parse(File.read('tools/sidmod_editor/sprites/missing.json'))

require_relative '../sim/engine'
SimEngine.boot
$DEBUG = false

puts "Settings::CUSTOM_BATTLERS_FOLDER_INDEXED = #{Settings::CUSTOM_BATTLERS_FOLDER_INDEXED.inspect}"
puts "resolving the path check_for_local_sprite builds, via the engine's pbResolveBitmap:\n\n"

ok = 0
dex_ok = 0
fail = []
missing.each do |r|
  head, body = r['head'], r['body']
  name = "#{r['head_name']}/#{r['body_name']}"
  # exactly as BattleSpriteLoader#check_for_local_sprite builds it (alt_letter "")
  battle_path = "#{Settings::CUSTOM_BATTLERS_FOLDER_INDEXED}#{head}/#{head}.#{body}.png"
  # exactly as PokedexUtils#getLocalFusionSpriteAlts builds it (note the extra slash)
  dex_path    = "#{Settings::CUSTOM_BATTLERS_FOLDER_INDEXED}/#{head}/#{head}.#{body}.png"

  battle = pbResolveBitmap(battle_path)
  dex    = pbResolveBitmap(dex_path)
  ok += 1 if battle
  dex_ok += 1 if dex
  fail << "#{head}.#{body}" unless battle

  puts format("  %-9s %-32s battle=%-3s dex=%-3s", "#{head}.#{body}", name,
              battle ? "OK" : "--", dex ? "OK" : "--")
end

puts "\nbattle sprite : #{ok}/#{missing.size} resolve"
puts "pokedex alt   : #{dex_ok}/#{missing.size} resolve"
puts "still unresolved: #{fail.join(', ')}" unless fail.empty?
puts ok == missing.size ? "ALL GOOD — the game loads these as :CUSTOM sprites in battle." :
                          "INCOMPLETE — the listed fusions will still fall back to autogen."
