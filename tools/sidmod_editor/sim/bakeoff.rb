# OU Balance slot-2 breaker bake-off: Marokyu vs Snorlax/Garchomp vs Hydreigon/Gardevoir.
# Best-of-3 vs the 4 OU-tier opponents only (Ubers matchups excluded - unwinnable, uninformative).
# Battle signal is DIRECTIONAL: low sample + imperfect pilot + skewed opponent pool. Read alongside
# the static competitive analysis, not as the sole arbiter.
require_relative 'build_team'; require_relative 'agent_battle'; require_relative 'editor'; require_relative 'roster'
SimEngine.boot; $DEBUG = false
FIELD = ClaudeClient::PARSE.call(File.read(File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')))

BASE_PLAN = "OU BALANCE. Ferrothorn/Skarmory sets hazards (SR/Spikes)+Whirlwind phazes; Gliscor/Suicune (Poison Heal) walls+pivots; Rotom/Gyarados (Levitate) VoltTurns+Will-O-Wisp; Starmie/Tentacruel Rapid-Spins (hazard control); Dragonite/Scizor (Multiscale Dragon Dance) is a win-con. Wear them down with hazards+walls, then sweep. Your SLOT-2 BREAKER: "
VARIANTS = {
  "Marokyu" => {
    mon: {"head"=>"MAROWAK","body"=>"MIMIKYU","ability"=>"DISGUISE","item"=>"THICKCLUB","nature"=>"ADAMANT","moves"=>%w[SWORDSDANCE BONEMERANG PLAYROUGH SHADOWSNEAK],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252},"level"=>100},
    plan: "Marowak/Mimikyu - Disguise BLOCKS the first hit (free Swords Dance!), Thick Club DOUBLES Attack (Bonemerang Ground + Play Rough Fairy hit ENORMOUSLY, dual STAB), Shadow Sneak = priority. Switch it in behind Disguise, SD once, then sweep or Sneak-snipe." },
  "SnorChomp" => {
    mon: {"head"=>"SNORLAX","body"=>"GARCHOMP","ability"=>"THICKFAT","item"=>"LEFTOVERS","nature"=>"ADAMANT","moves"=>%w[DRAGONDANCE RETURN EARTHQUAKE CRUNCH],"evs"=>{"HP"=>4,"ATTACK"=>252,"SPEED"=>252},"level"=>100},
    plan: "Snorlax/Garchomp - BULKY Dragon Dance sweeper; Thick Fat makes it near Ice-proof and its 425 HP tanks hits, so set up Dragon Dance when safe then sweep with Return/Earthquake/Crunch. Very hard to revenge - be patient, DD then clean." },
  "HydraGarde" => {
    mon: {"head"=>"HYDREIGON","body"=>"GARDEVOIR","ability"=>"LEVITATE","item"=>"LIFEORB","nature"=>"MODEST","moves"=>%w[CALMMIND MOONBLAST DARKPULSE FLASHCANNON],"evs"=>{"HP"=>4,"SPECIAL_ATTACK"=>252,"SPEED"=>252},"level"=>100},
    plan: "Hydreigon/Gardevoir - SPECIAL Calm Mind breaker (Dark/Fairy, Levitate=Ground-immune, immune Psychic/Dragon). Calm Mind when safe, then Moonblast/Dark Pulse nuke walls. Complements the physical Dragonite/Scizor - use it to break special walls." },
}
OPP = %w[OU OURain OUSun OUSand]

def variant_team(mon)
  t = FIELD['OUBalance'].map { |m| Editor.normalize(m) }
  t[1] = Editor.normalize(mon)
  BuildTeam.team(t)
end

puts "=== OU Balance slot-2 bake-off (best-of-3 vs OU-tier) ==="
totals = Hash.new { |h, k| h[k] = { w: 0, l: 0, d: 0 } }
VARIANTS.each do |vname, v|
  plan = BASE_PLAN + v[:plan]
  OPP.each do |opp|
    _dec, _log, tally = SimAgent.series(
      -> { variant_team(v[:mon]) }, -> { BuildTeam.team(FIELD[opp].map { |m| Editor.normalize(m) }) },
      SimAgent.claude_policy(plan, model: 'claude-sonnet-5'),
      SimAgent.claude_policy(Roster.plan(opp), model: 'claude-sonnet-5'),
      games: 3, cap: 55)
    res = tally[:a] > tally[:b] ? :w : (tally[:b] > tally[:a] ? :l : :d)
    totals[vname][res] += 1
    puts "  #{vname.ljust(11)} vs #{opp.ljust(7)}: #{tally[:a]}-#{tally[:b]}-#{tally[:draw]}  (#{res.to_s.upcase})"
  end
end
puts "\n=== TOTALS (series W-L-D vs 4 OU-tier opponents) ==="
totals.each { |v, t| puts "  #{v.ljust(11)}: #{t[:w]}W-#{t[:l]}L-#{t[:d]}D" }
