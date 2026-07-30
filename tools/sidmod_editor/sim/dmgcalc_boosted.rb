# (1) Entei/Arcanine both fusion orders: stats/types/abilities/movepool.
# (2) Boosted MAIN moves (not priority) vs the tankiest walls — where wallbreaking
#     actually happens. Deterministic damage math.
require_relative 'nstore'
require_relative 'nbattle'
require_relative 'build_team'

ENV['NSIM_SAVE'] = File.join(__dir__, 'nreports', 'ladder_ou6', 'save_snapshot.rxdata')
NativeSim.boot!
$DEBUG = false
GameData::Species.send(:public, :get_baby_species)

class PokeBattle_Move
  def pbIsCritical?(user, target); false; end
end

# ---- (1) Entei/Arcanine fusion order comparison ----
puts "==== ENTEI / ARCANINE — fusion order comparison ===="
[[:ENTEI, :ARCANINE], [:ARCANINE, :ENTEI]].each do |head, body|
  hd = GameData::Species.get(head).id_number; bd = GameData::Species.get(body).id_number
  fid = getFusedPokemonIdFromDexNum(bd, hd); fs = GameData::Species.get(fid)
  pool = (pbGetLegalMoves(head) + pbGetLegalMoves(body)).uniq
  key = %i[SACREDFIRE EXTREMESPEED FLAREBLITZ MORNINGSUN WILDCHARGE CRUNCH CLOSECOMBAT WILLOWISP ROAR]
  s = fs.base_stats
  puts "  #{head}/#{body} => #{fs.name}  #{fs.types.join('/')}  BST #{s.values.sum}"
  puts "    HP#{s[:HP]} Atk#{s[:ATTACK]} Def#{s[:DEFENSE]} SpA#{s[:SPECIAL_ATTACK]} SpD#{s[:SPECIAL_DEFENSE]} Spe#{s[:SPEED]}"
  puts "    abilities: #{(fs.abilities+fs.hidden_abilities).uniq.join(', ')}"
  puts "    key moves: #{key.select{|m| pool.include?(m)}.join(', ')}"
end

# ---- (2) boosted main-move calc ----
def refpk(name)
  e = NativeSim.all_pool.find { |x| x[:name] == name } or return nil
  pk = Marshal.load(Marshal.dump(e[:ref])); pk.heal; pk
end

def calc(att, dfn, move_id, stage, roll, hits=1)
  t1 = SimBattle.make_trainer('P1',[att]); t2 = SimBattle.make_trainer('P2',[dfn])
  b = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
  b.debug=true; b.controlPlayer=true; b.internalBattle=false
  b.define_singleton_method(:pbRandom){|x| roll<x ? roll : x-1}
  b.pbCreateBattler(0,att,0); b.pbCreateBattler(1,dfn,0)
  u=b.battlers[0]; tg=b.battlers[1]; u.stages[:ATTACK]=stage
  mv=PokeBattle_Move.from_pokemon_move(b, Pokemon::Move.new(move_id))
  tg.damageState.reset
  ct=mv.pbCalcType(u); mv.instance_variable_set(:@calcType,ct)
  tmod=mv.pbCalcTypeMod(ct,u,tg); tg.damageState.typeMod=tmod
  return [:immune,0.0] if Effectiveness.ineffective?(tmod)
  mv.pbCalcDamage(u,tg); d=tg.damageState.calcDamage*hits
  eff = Effectiveness.super_effective?(tmod) ? 'SE' : (Effectiveness.not_very_effective?(tmod) ? 'resist' : 'neu')
  [eff, 100.0*d/tg.totalhp]
end
def verdict(lo,hi)
  return 'IMMUNE' if lo==:immune
  if lo>=100 then 'OHKO' elsif hi>=100 then "#{(100.0*(hi-100)/(hi-lo)).round}%OHKO"
  elsif lo>=50 then '2HKO' elsif hi>=50 then 'poss2HKO' else "#{(100.0/hi).ceil}HKO" end
end

# attacker => [ [move, stage, hits], ... ]
PLAN = {
  'Bonecloak'   => [[:BONEMERANG,2,2],[:PLAYROUGH,2,1]],
  'Abyssmarill' => [[:PLAYROUGH,2,1]],
  'Lagoonking'  => [[:WATERFALL,0,1],[:EARTHQUAKE,0,1]],
  'Infermane'   => [[:SACREDFIRE,0,1],[:WILDCHARGE,0,1],[:CRUNCH,0,1]],
}
WALLS = %w[Pinkreef Phantomguard Aqualift Aqueon Steelwyrm Glissey Dragotitan]

puts "\n==== BOOSTED MAIN MOVES vs the tankiest walls ===="
PLAN.each do |aname, moves|
  att = refpk(aname) or next
  puts "\n-- #{aname} (Atk #{att.attack}, #{att.item&.id}) --"
  moves.each do |mid, stage, hits|
    WALLS.each do |dname|
      next if dname==aname
      dfn = refpk(dname) or next
      lo_e,lo = calc(att,dfn,mid,stage,0,hits); hi_e,hi = calc(att,dfn,mid,stage,15,hits)
      tag = lo_e==:immune ? 'IMMUNE' : "#{lo_e.ljust(6)} #{'%.0f'%lo}-#{'%.0f'%hi}%  #{verdict(lo,hi)}"
      puts "   #{mid.to_s.ljust(12)}+#{stage} vs #{dname.ljust(12)}(#{dfn.types.join('/').ljust(13)}HP#{dfn.totalhp}) #{tag}"
    end
  end
end
