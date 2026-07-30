# Does stacked-multiplier priority actually OHKO the field? Fire the real meta
# priority moves (at +2 post-setup AND +0) at the tankiest ladder walls / type-answers,
# using their ACTUAL pool builds. Deterministic damage math — no AI involved.
require_relative 'nstore'
require_relative 'nbattle'

ENV['NSIM_SAVE'] = File.join(__dir__, 'nreports', 'ladder_ou6', 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false

class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end

# attacker name => priority move it actually runs
ATTACKERS = {
  'Bonecloak'   => :SHADOWSNEAK,   # Marowak/Mimikyu, Thick Club, Ghost priority
  'Abyssmarill' => :AQUAJET,       # Azumarill/Absol, Huge Power, Water priority
  'Glimmerwing' => :EXTREMESPEED,  # Sylveon/Dragonite, Pixilate -> Fairy priority
  'Voltario'    => :EXTREMESPEED,  # Lucario/Pikachu, Light Ball, Normal->? priority
}
# tankiest walls + key type-answers on the ladder
DEFENDERS = %w[Pinkreef Phantomguard Aqualift Aqueon Steelwyrm Glissey Bonecloak Dragotitan]

def ref(name)
  e = NativeSim.all_pool.find { |x| x[:name] == name } or return nil
  pk = Marshal.load(Marshal.dump(e[:ref])); pk.heal; pk
end

def calc(att, dfn, move_id, atk_stage, roll)
  t1 = SimBattle.make_trainer('P1', [att]); t2 = SimBattle.make_trainer('P2', [dfn])
  battle = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
  battle.debug = true; battle.controlPlayer = true; battle.internalBattle = false
  battle.define_singleton_method(:pbRandom) { |x| roll < x ? roll : x - 1 }
  battle.pbCreateBattler(0, att, 0); battle.pbCreateBattler(1, dfn, 0)
  u = battle.battlers[0]; tg = battle.battlers[1]
  u.stages[:ATTACK] = atk_stage rescue (u.stages[0] = atk_stage rescue nil)
  mv = PokeBattle_Move.from_pokemon_move(battle, Pokemon::Move.new(move_id))
  tg.damageState.reset
  ct = mv.pbCalcType(u); mv.instance_variable_set(:@calcType, ct)
  tmod = mv.pbCalcTypeMod(ct, u, tg); tg.damageState.typeMod = tmod
  return [:immune, 0.0, ct] if Effectiveness.ineffective?(tmod)
  mv.pbCalcDamage(u, tg)
  d = tg.damageState.calcDamage
  eff = Effectiveness.super_effective?(tmod) ? 'SE' : (Effectiveness.not_very_effective?(tmod) ? 'resist' : 'neutral')
  [eff, 100.0 * d / tg.totalhp, ct]
end

def verdict(lo, hi)
  return 'IMMUNE' if lo == :immune
  if lo >= 100 then 'OHKO'
  elsif hi >= 100 then "#{(100.0*(hi-100)/(hi-lo)).round}%-roll OHKO"
  elsif lo >= 50 then '2HKO'
  elsif hi >= 50 then 'poss 2HKO'
  else "survives (#{(100.0/hi).ceil}HKO)" end
end

ATTACKERS.each do |aname, mv|
  att = ref(aname) or next
  puts "\n=== #{aname} — #{mv} (Atk #{att.attack}, item #{att.item&.id}) ==="
  DEFENDERS.each do |dname|
    next if dname == aname
    dfn = ref(dname) or next
    [2, 0].each do |stage|
      lo_eff, lo_pct, ct = calc(att, dfn, mv, stage, 0)
      hi_eff, hi_pct, _  = calc(att, dfn, mv, stage, 15)
      if lo_eff == :immune
        puts "  +#{stage}  vs #{dname.ljust(13)} (#{dfn.types.map(&:to_s).join('/').ljust(14)} HP#{dfn.totalhp})  IMMUNE (#{ct})"
        break
      end
      puts "  +#{stage}  vs #{dname.ljust(13)} (#{dfn.types.map(&:to_s).join('/').ljust(14)} HP#{dfn.totalhp})  #{lo_eff.ljust(7)} #{'%.0f' % lo_pct}-#{'%.0f' % hi_pct}%  #{verdict(lo_pct, hi_pct)}"
    end
  end
end
