# Ground-truth fusion inspector: given a candidate spec, actually BUILD it in the engine
# and report the REAL typing, stats (vs both parents), resolved ability, weaknesses, and a
# set of auto-flags (dilution / dead-ability / 4x-weak / invalid). This is the "try it out
# and look at the result" oracle the coach loop calls before committing a change.
require_relative 'build_team'
require_relative 'editor'

module Inspect
  module_function

  TYPES18 = %i[NORMAL FIRE WATER ELECTRIC GRASS ICE FIGHTING POISON GROUND FLYING
               PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY]

  # recoil moves that make Rock Head / Reckless meaningful
  RECOIL = %i[DOUBLEEDGE FLAREBLITZ BRAVEBIRD WOODHAMMER HEADSMASH VOLTTACKLE WILDCHARGE
              TAKEDOWN SUBMISSION HEADCHARGE LIGHTOFRUIN STRUGGLE HIGHJUMPKICK JUMPKICK]
  WEATHER_ABIL = { SWIFTSWIM: "rain", CHLOROPHYLL: "sun", SANDRUSH: "sand", SLUSHRUSH: "hail/snow",
                   SANDFORCE: "sand", SOLARPOWER: "sun", RAINDISH: "rain", DRYSKIN: "rain (heals)/sun (hurts)",
                   LEAFGUARD: "sun", ICEBODY: "hail/snow" }
  ORB_ABIL   = %i[POISONHEAL GUTS QUICKFEET FLAREBOOST TOXICBOOST MARVELSCALE]

  def stat_hash(pk)
    { atk: pk.attack, def: pk.defense, spa: pk.spatk, spd: pk.spdef, spe: pk.speed, hp: pk.totalhp }
  end

  def types_of(pk)
    (pk.types rescue [pk.type1, pk.type2]).compact.map { |t| t.respond_to?(:id) ? t.id : t }
  end

  # 4x/2x/0x weaknesses & resistances of a defending type combo
  def matchups(t1, t2)
    weak4 = []; weak2 = []; immune = []
    TYPES18.each do |atk|
      m = (Effectiveness.calculate(atk, t1, t2).to_f / Effectiveness::NORMAL_EFFECTIVE)
      if    m == 0     then immune << atk
      elsif m >= 4     then weak4  << atk
      elsif m >= 2     then weak2  << atk
      end
    end
    { x4: weak4, x2: weak2, immune: immune }
  end

  def abilities_of(sp)
    s = (GameData::Species.get(sp) rescue nil)
    return [] unless s
    (Array((s.abilities rescue nil)) + Array((s.hidden_abilities rescue nil))).flatten.compact.map { |a| a.respond_to?(:id) ? a.id : a }
  end

  # Main entry: returns a Hash describing the built fusion + flags. Never raises.
  def check(raw)
    s = Editor.normalize(raw)
    out = { spec: { head: s[:head], body: s[:body], species: s[:species], ability: s[:ability],
                    item: s[:item], nature: s[:nature], moves: s[:moves] }, flags: [], ok: true }

    # validity first
    bad_sp = [s[:head], s[:body], s[:species]].compact.reject { |sp| Editor.valid_species?(sp) }
    bad_mv = (s[:moves] || []).reject { |mv| GameData::Move.exists?(mv) rescue false }
    unless bad_sp.empty? && bad_mv.empty?
      out[:ok] = false
      out[:flags] << "INVALID species=#{bad_sp.join(',')} moves=#{bad_mv.join(',')}"
      return out
    end

    pk = BuildTeam.mon(s)
    ft = types_of(pk)
    out[:typing]  = ft.map(&:to_s).join('/')
    out[:ability] = (pk.ability&.id).to_s
    fst = stat_hash(pk)
    out[:stats]   = fst
    mu = matchups(ft[0], ft[1])
    out[:weak_x4] = mu[:x4].map(&:to_s); out[:weak_x2] = mu[:x2].map(&:to_s); out[:immune] = mu[:immune].map(&:to_s)

    if s[:head] && s[:body]
      parents = {}
      [s[:head], s[:body]].each do |par|
        mono = (BuildTeam.mon({ species: par, nature: s[:nature], level: 100 }) rescue nil)
        next unless mono
        pt = types_of(mono)
        parents[par] = { types: pt.map(&:to_s).join('/'), stats: stat_hash(mono),
                         typeset: pt.sort, matchups: matchups(pt[0], pt[1]) }
      end
      out[:parents] = parents

      # ---- FLAG: typing offers nothing new (fusion typing == a parent's typing) ----
      fset = ft.sort
      parents.each { |par, d| out[:flags] << "TYPING-NO-GAIN: matches mono #{par} (#{d[:types]})" if d[:typeset] == fset }

      # ---- FLAG: stat dilution (fusion key offensive stat far below the better parent) ----
      better = ->(k) { parents.values.map { |d| d[:stats][k] }.max }
      %i[atk spa spe].each do |k|
        b = better.(k); f = fst[k]
        out[:flags] << "STAT-TAX #{k.upcase}: #{f} (best parent #{b}, -#{b - f})" if b && f < b - 25
      end

      # ---- FLAG: fusion introduces a 4x weakness neither parent had ----
      pw4 = parents.values.flat_map { |d| d[:matchups][:x4] }.uniq
      new4 = mu[:x4] - pw4
      out[:flags] << "NEW-4x-WEAK: #{new4.map(&:to_s).join(',')} (not on either parent)" unless new4.empty?
    end

    out[:flags] << "4x-WEAK: #{mu[:x4].map(&:to_s).join(',')}" unless mu[:x4].empty?

    # ---- FLAG: dead / mismatched ability ----
    ab = (pk.ability&.id)
    if ab == :ROCKHEAD && (s[:moves] & RECOIL).empty?
      out[:flags] << "DEAD-ABILITY: ROCKHEAD but no recoil move in set (#{s[:moves].join('/')})"
    end
    if ORB_ABIL.include?(ab) && !%i[TOXICORB FLAMEORB].include?(s[:item])
      out[:flags] << "ABILITY-NEEDS-ORB: #{ab} wants Toxic/Flame Orb, item is #{s[:item]}"
    end
    if WEATHER_ABIL.key?(ab)
      out[:flags] << "WEATHER-ABILITY: #{ab} only active in #{WEATHER_ABIL[ab]} — team must set it"
    end

    # ---- FLAG: ability not native to either parent (still legal in IF, but worth noting) ----
    if s[:head] && s[:body] && ab
      native = (abilities_of(s[:head]) + abilities_of(s[:body])).uniq
      forced_weather = %i[DRIZZLE DROUGHT SANDSTREAM SNOWWARNING].include?(ab)
      out[:flags] << "OFF-PARENT-ABILITY: #{ab} not native to #{s[:head]}/#{s[:body]} (#{native.join(',')})" unless native.include?(ab) || forced_weather || WEATHER_ABIL.key?(ab)
    end

    out
  end

  # Compact human/LLM-readable rendering of a check result.
  def render(r)
    return "  spec: #{r[:spec].inspect}\n  #{r[:flags].join("\n  ")}" unless r[:ok]
    lines = []
    sp = r[:spec]
    name = sp[:head] && sp[:body] ? "#{sp[:head]}/#{sp[:body]}" : sp[:species].to_s
    lines << "#{name} @#{sp[:item]} [#{r[:ability]}] #{sp[:nature]}  moves=#{Array(sp[:moves]).join('/')}"
    lines << "  TYPING: #{r[:typing]}"
    st = r[:stats]
    lines << "  STATS : Atk#{st[:atk]} Def#{st[:def]} SpA#{st[:spa]} SpD#{st[:spd]} Spe#{st[:spe]} HP#{st[:hp]}"
    if r[:parents]
      r[:parents].each { |par, d| s2 = d[:stats]
        lines << "    mono #{par.to_s.ljust(11)} #{d[:types].ljust(14)} Atk#{s2[:atk]} Def#{s2[:def]} SpA#{s2[:spa]} SpD#{s2[:spd]} Spe#{s2[:spe]} HP#{s2[:hp]}" }
    end
    lines << "  WEAK  : 4x[#{r[:weak_x4].join(',')}] 2x[#{r[:weak_x2].join(',')}] immune[#{r[:immune].join(',')}]"
    lines << (r[:flags].empty? ? "  FLAGS : none" : "  FLAGS :\n    - " + r[:flags].join("\n    - "))
    lines.join("\n")
  end
end

# CLI: ruby fusion_inspector.rb  (runs a few probes, incl. the audit-flagged fusions)
if __FILE__ == $0
  SimEngine.boot
  $DEBUG = false
  probes = [
    { head: "KYUREM", body: "METAGROSS", ability: "CLEARBODY", item: "CHOICESCARF", nature: "JOLLY",
      moves: %w[ICICLECRASH DRAGONCLAW EARTHQUAKE IRONHEAD] },
    { head: "RHYPERIOR", body: "SALAMENCE", ability: "ROCKHEAD", item: "CHOICEBAND", nature: "ADAMANT",
      moves: %w[EARTHQUAKE STONEEDGE MEGAHORN ICEPUNCH] },
    { head: "PALKIA", body: "FLYGON", ability: "DRYSKIN", item: "LIFEORB", nature: "MODEST",
      moves: %w[CALMMIND SURF DRACOMETEOR FLAMETHROWER] },
    { head: "GLISCOR", body: "MILOTIC", ability: "POISONHEAL", item: "TOXICORB", nature: "IMPISH",
      moves: %w[EARTHQUAKE TOXIC ROOST PROTECT] },
    { head: "DRAGONITE", body: "SCIZOR", ability: "MULTISCALE", item: "LEFTOVERS", nature: "ADAMANT",
      moves: %w[DRAGONDANCE DRAGONCLAW EARTHQUAKE ROOST] },
  ]
  probes.each { |p| puts Inspect.render(Inspect.check(p)); puts }
end
