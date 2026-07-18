# Agent-driven battles: replace the game AI's per-turn choice with an external
# policy (random now, Claude API next). Proves the injection hook before spending
# any tokens. Policies are procs (battle, idxBattler, state) -> [:move, idx] | [:switch, idx].
require_relative 'battle'
require_relative 'claude_client'

module SimAgent
  module_function

  CAT = { 0 => "Physical", 1 => "Special", 2 => "Status" }

  def build_prompt(st, team_plan)
    me = st["me"]; foe = st["foe"]
    l = []
    l << "WEATHER: #{st['weather']}"
    l << "YOU: #{me['name']} HP #{me['hp']}% status=#{me['status']} ability=#{me['ability']} item=#{me['item']}"
    l << "YOUR MOVES:"
    st["moves"].each { |m| l << "  [#{m['idx']}] #{m['id']} #{m['type']}/#{CAT[m['cat']]} pow#{m['pow']} pp#{m['pp']} -> vs_foe: #{m['eff']}" }
    unless st["switches"].empty?
      l << "SWITCH OPTIONS:"
      st["switches"].each { |s| l << "  [#{s['idx']}] #{s['name']} #{s['hp']}%HP" }
    end
    l << "OPPONENT: #{foe['name']} HP #{foe['hp']}% status=#{foe['status']} types=#{foe['types'].join('/')}"
    l << "PLAN: #{team_plan}" if team_plan && !team_plan.empty?
    l << 'Pick the single best action. Respond ONLY with JSON: {"reason":"<=12 words","action":"move"|"switch","idx":<int>}'
    l.join("\n")
  end

  def claude_policy(team_plan = "", model: "claude-haiku-4-5-20251001")
    system = "You are an elite competitive Pokemon battler. This is Pokemon Infinite Fusion: fusions combine both parents' stats, movepools and abilities. Weather set by an ability is PERMANENT until another weather ability overwrites it. Each of your moves lists 'vs_foe' effectiveness against the CURRENT opponent: NEVER choose an IMMUNE move; strongly prefer SUPER, avoid RESISTED unless setting up/pivoting. If you are Choice-locked into a move that is now IMMUNE or badly resisted, SWITCH instead of wasting turns. Do NOT over-set-up: after about +2 boosts, ATTACK - a sweeper that keeps boosting instead of KOing wins nothing; only keep boosting if it's clearly safe AND lethal next turn. Win by exploiting types, weather wars, setup, priority, and predicting switches. Output ONLY the single-line JSON object, no preamble or text around it."
    lambda do |battle, i, st|
      # Forced turns need no LLM: skip the API call when there is only one legal action.
      lm = st["moves"]; sw = st["switches"]
      if lm.length == 1 && sw.empty?
        $SIM_LAST_REASON = "(forced)"; return [:move, lm[0]["idx"]]
      elsif lm.empty?
        $SIM_LAST_REASON = "(forced)"; return random_policy(battle, i, st)
      end
      begin
        txt = ClaudeClient.complete(system: system, user: build_prompt(st, team_plan), model: model, max_tokens: 150)
        j = ClaudeClient.json_parse(txt[/\{.*\}/m])
        idx = j["idx"].to_i
        act = (j["action"] == "switch") ? [:switch, idx] : [:move, idx]
        $SIM_LAST_REASON = j["reason"]
        legal = (act[0] == :move) ? legal_moves(battle, i).include?(idx) : legal_switches(battle, i).include?(idx)
        legal ? act : random_policy(battle, i, st)
      rescue => e
        $SIM_LAST_REASON = "(fallback: #{e.message[0, 40]})"
        random_policy(battle, i, st)
      end
    end
  end

  def install!
    return if @installed
    eval(<<~RUBY, TOPLEVEL_BINDING)
      class PokeBattle_AI
        alias_method :sim_orig_choose, :pbDefaultChooseEnemyCommand unless method_defined?(:sim_orig_choose)
        def pbDefaultChooseEnemyCommand(idxBattler)
          if $SIM_DECIDE
            $SIM_DECIDE.call(@battle, idxBattler)
          else
            sim_orig_choose(idxBattler)
          end
        end
      end
    RUBY
    @installed = true
  end

  def legal_moves(battle, i)
    b = battle.battlers[i]
    (0...b.moves.length).select do |mi|
      m = b.moves[mi]
      m && m.id && m.id != :NONE && (battle.pbCanChooseMove?(i, mi, false) rescue true)
    end
  end

  def legal_switches(battle, i)
    party = battle.pbParty(i)
    (0...party.length).select { |pi| (battle.pbCanSwitch?(i, pi) rescue false) }
  end

  def pct(b)
    (b && b.totalhp > 0) ? (100.0 * b.hp / b.totalhp).round : 0
  end

  # Compact battle state for side of battler i (also the future LLM prompt payload).
  def eff_label(v)
    return "IMMUNE" if v == 0
    mult = v / 8.0
    return "1x" if mult == 1
    mult < 1 ? "#{mult}x-RESISTED" : "#{mult}x-SUPER"
  end

  def state(battle, i)
    me  = battle.battlers[i]
    foe = (battle.battlers[i ^ 1] rescue nil) || battle.battlers.find { |b| b && b.index != i }
    ftypes = (foe.pbTypes(true) rescue [])

    moves = legal_moves(battle, i).map do |mi|
      m = me.moves[mi]
      eff = m.category == 2 ? "status" : (eff_label(Effectiveness.calculate(m.type, *ftypes)) rescue "?")
      { "idx" => mi, "id" => m.id.to_s, "type" => (m.type.to_s rescue ""),
        "cat" => m.category, "pow" => (m.baseDamage rescue 0), "pp" => m.pp, "eff" => eff }
    end
    switches = legal_switches(battle, i).map do |pi|
      pk = battle.pbParty(i)[pi]
      { "idx" => pi, "name" => pk.speciesName, "hp" => (pk.hp * 100 / [pk.totalhp, 1].max) }
    end

    me_name  = (me.pbThis(true) rescue me.pokemon.speciesName)
    foe_name = (foe.pbThis(true) rescue foe.pokemon.speciesName)
    me_abil  = ((me.ability && me.ability.id).to_s rescue "")
    me_item  = ((me.item && me.item.id).to_s rescue "")
    foe_types = (foe.pbTypes(true).map(&:to_s) rescue [])
    weather  = (battle.field.weather.to_s rescue (battle.pbWeather.to_s rescue ""))

    {
      "me"  => { "name" => me_name, "hp" => pct(me), "status" => me.status.to_s, "ability" => me_abil, "item" => me_item },
      "foe" => { "name" => foe_name, "hp" => pct(foe), "status" => foe.status.to_s, "types" => foe_types },
      "weather" => weather, "moves" => moves, "switches" => switches
    }
  end

  def apply(battle, i, action)
    kind, idx = action
    if kind == :switch && legal_switches(battle, i).include?(idx)
      battle.pbRegisterSwitch(i, idx)
    elsif kind == :move && legal_moves(battle, i).include?(idx)
      battle.pbRegisterMove(i, idx)
    else
      battle.pbAutoChooseMove(i)
    end
  end

  def random_policy(battle, i, st)
    mv = st["moves"]
    return [:switch, st["switches"].first["idx"]] if mv.empty? && !st["switches"].empty?
    return [:move, mv.sample["idx"]] unless mv.empty?
    [:move, 0]
  end

  # Run a battle with two side-policies. Returns [decision, actions_log].
  def run(team1, team2, policy1 = method(:random_policy), policy2 = method(:random_policy), seed: nil, cap: nil)
    install!
    srand(seed) if seed
    log = []
    count = 0
    $SIM_DECIDE = lambda do |battle, i|
      count += 1
      st = state(battle, i)
      side = (battle.pbOwnedByPlayer?(i) ? 0 : 1)
      $SIM_LAST_REASON = nil
      # cost cap: after N decisions, fall back to the fast local policy to end the game
      pol = (cap && count > cap) ? method(:random_policy) : (side == 0 ? policy1 : policy2)
      action = pol.call(battle, i, st)
      lbl = action[0] == :move ? ((st["moves"].find { |m| m["idx"] == action[1] } || {})["id"] || "?") : "switch->#{action[1]}"
      reason = $SIM_LAST_REASON ? "  \"#{$SIM_LAST_REASON}\"" : ""
      log << "  side#{side} #{st["me"]["name"]} (#{st["me"]["hp"]}%) -> #{lbl}#{reason}"
      apply(battle, i, action)
    end
    dec = SimBattle.run(team1, team2)
    $SIM_DECIDE = nil
    [dec, log]
  end

  # Best-of-N to cut single-game noise. build1/build2 are thunks returning a FRESH team
  # (Pokemon get mutated in battle, so each game needs new objects). Returns
  # [majority_dec (1|2|5), combined_log, tally_hash]. Each game uses a distinct seed.
  def series(build1, build2, policy1, policy2, games: 3, cap: nil)
    tally = { a: 0, b: 0, draw: 0 }
    logs = []
    games.times do |g|
      dec, log = run(build1.call, build2.call, policy1, policy2, seed: g + 1, cap: cap)
      key = dec == 1 ? :a : dec == 2 ? :b : :draw
      tally[key] += 1
      logs << "----- game #{g + 1} (seed #{g + 1}): winner=#{key} -----"
      logs.concat(log)
    end
    winner = tally[:a] > tally[:b] ? 1 : tally[:b] > tally[:a] ? 2 : 5
    [winner, logs, tally]
  end
end
