# Build a FOCUSED arena: Degen (max-broken fusion) + OU control + Ubers controls + our 2 best.
# Answers: can weaponized fusions beat Ubers? where does OU land? Writes reports/arena/field_specs.json
require 'json'; require 'fileutils'
HF = JSON.parse(File.read(File.join(__dir__, 'reports', 'hf', 'field_specs.json')))  # parse before boot
require_relative 'build_team'
require_relative 'editor'
SimEngine.boot
$DEBUG = false
OUT = File.join(__dir__, 'reports', 'arena'); FileUtils.mkdir_p(OUT)

field = {}
# our best 2 + the 2 Ubers controls (pull from hf)
%w[Squads Box15A UbersOff UbersBal].each { |t| field[t] = HF[t] }

# DEGEN: stack the broken interactions (two-uber near-max fusions + Thick Club + Poison Heal + Magic Guard)
field['Degen'] = [
  { "head"=>"KYOGRE","body"=>"ARCEUS","ability"=>"DRIZZLE","item"=>"CHOICESPECS","nature"=>"MODEST","moves"=>%w[WATERSPOUT SURF ICEBEAM JUDGMENT],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "head"=>"MAROWAK","body"=>"ARCEUS","ability"=>"ROCKHEAD","item"=>"THICKCLUB","nature"=>"ADAMANT","moves"=>%w[SWORDSDANCE EXTREMESPEED EARTHQUAKE STONEEDGE],"evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "head"=>"REGIGIGAS","body"=>"GLISCOR","ability"=>"POISONHEAL","item"=>"TOXICORB","nature"=>"ADAMANT","moves"=>%w[SWORDSDANCE FACADE EARTHQUAKE KNOCKOFF],"evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "head"=>"MEWTWO","body"=>"ARCEUS","ability"=>"PRESSURE","item"=>"LIFEORB","nature"=>"TIMID","moves"=>%w[NASTYPLOT AURASPHERE ICEBEAM JUDGMENT],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "head"=>"LUGIA","body"=>"GROUDON","ability"=>"MULTISCALE","item"=>"LEFTOVERS","nature"=>"ADAMANT","moves"=>%w[DRAGONDANCE EARTHQUAKE STONEEDGE ROOST],"evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "head"=>"RESHIRAM","body"=>"CLEFABLE","ability"=>"MAGICGUARD","item"=>"LIFEORB","nature"=>"MODEST","moves"=>%w[CALMMIND FUSIONFLARE MOONBLAST EARTHPOWER],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
]
# OU: standard BW OU balance (sand + hazards + Gliscor stall + Latios + Band Scizor + Jirachi)
field['OU'] = [
  { "species"=>"TYRANITAR","ability"=>"SANDSTREAM","item"=>"CHOICESCARF","nature"=>"JOLLY","moves"=>%w[CRUNCH STONEEDGE PURSUIT FIREBLAST],"evs"=>{"ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"FERROTHORN","ability"=>"IRONBARBS","item"=>"LEFTOVERS","nature"=>"RELAXED","moves"=>%w[STEALTHROCK SPIKES LEECHSEED POWERWHIP],"evs"=>{"HP"=>252,"DEFENSE"=>252,"SPECIAL_DEFENSE"=>4},"level"=>100 },
  { "species"=>"GLISCOR","ability"=>"POISONHEAL","item"=>"TOXICORB","nature"=>"IMPISH","moves"=>%w[EARTHQUAKE TOXIC ROOST PROTECT],"evs"=>{"HP"=>252,"DEFENSE"=>252,"SPEED"=>4},"level"=>100 },
  { "species"=>"LATIOS","ability"=>"LEVITATE","item"=>"LIFEORB","nature"=>"TIMID","moves"=>%w[DRACOMETEOR PSYSHOCK SURF ROOST],"evs"=>{"SPECIAL_ATTACK"=>252,"SPEED"=>252,"HP"=>4},"level"=>100 },
  { "species"=>"SCIZOR","ability"=>"TECHNICIAN","item"=>"CHOICEBAND","nature"=>"ADAMANT","moves"=>%w[BULLETPUNCH UTURN SUPERPOWER PURSUIT],"evs"=>{"ATTACK"=>252,"HP"=>252,"SPEED"=>4},"level"=>100 },
  { "species"=>"JIRACHI","ability"=>"SERENEGRACE","item"=>"LEFTOVERS","nature"=>"JOLLY","moves"=>%w[IRONHEAD BODYSLAM FIREPUNCH WISH],"evs"=>{"HP"=>252,"SPEED"=>252,"ATTACK"=>4},"level"=>100 },
]

File.write(File.join(OUT, 'field_specs.json'), JSON.generate(field))
# validate all species + build
bad = []
field.each do |name, team|
  team.each do |m|
    [m['head'], m['body'], m['species']].compact.each { |sp| bad << "#{name}:#{sp}" unless Editor.valid_species?(sp.to_s.upcase.gsub(/[^A-Z0-9]/,'').to_sym) }
    begin; BuildTeam.mon(Editor.normalize(m)); rescue => e; bad << "#{name}: BUILD FAIL #{e.class}"; end
  end
end
puts bad.empty? ? "arena field OK (#{field.size} teams): #{field.keys.join(', ')}" : "INVALID: #{bad.uniq.join('; ')}"
