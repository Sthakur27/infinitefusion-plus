# NATIVE-AI battle harness (deterministic, NO LLM) for mass team search.
#
# Everything the searcher needs, booted ONCE per process:
#   NativeSim.boot!                      -> engine + save PC pool + both-sides SmartAI patch
#   NativeSim.pool(tier: :ou)            -> [entry, ...]  (entry[:key], [:name], [:cand], [:ref])
#   NativeSim.run(keysA, keysB, seed: n) -> telemetry hash (winner, turns, per-mon KOs/faints)
#
# Why a resident process: boot is 0.5s and a battle is ~0.2s, so booting per battle
# would triple the cost. One worker boots once and runs its whole shard.
#
# READ-ONLY on game files (shim.rb neuters save_data).
require 'fileutils'
require_relative 'engine'
require_relative 'battle'

module NativeSim
  module_function

  LIVE_SAVE = File.join(ENV['APPDATA'], 'infinitefusion', 'File A.rxdata')

  # Pool keys are (box, slot), so a save that changes mid-run silently invalidates
  # them — and the live save DOES change while the game is being played (observed:
  # a mon vanished from box 14 between the sweep and the tournament, crashing the
  # workers). Every run therefore freezes a copy and every process (driver +
  # workers, via NSIM_SAVE in the inherited env) reads that copy.
  def snapshot_save!(dir, live = LIVE_SAVE)
    FileUtils.mkdir_p(dir)
    snap = File.join(dir, 'save_snapshot.rxdata')
    FileUtils.cp(live, snap) unless File.exist?(snap)
    ENV['NSIM_SAVE'] = snap
    snap
  end

  def save_path_in_use; ENV['NSIM_SAVE'] || LIVE_SAVE; end
  SAVE = LIVE_SAVE   # back-compat

  def boot!(save_path = nil)
    save_path ||= save_path_in_use
    return self if @booted
    SimEngine.boot
    $DEBUG = false
    save = StubLoader.load_file(save_path)
    $PokemonStorage = save[:storage_system]
    patch_ai_both_sides!
    patch_replacement_symmetry!
    patch_faint_tracking!
    patch_logging!
    build_pool!
    @booted = true
    self
  end

  # The stock SmartTrainerAI gate exempts player-owned battlers (in-game the human
  # plays side 0). In an AI-vs-AI sim that would put vanilla AI on side 0 and Smart
  # AI on side 1 — a silent, huge asymmetry. Drop the ownership clause only.
  def patch_ai_both_sides!
    return if @ai_patched
    class << PokeBattle_AI; end
    PokeBattle_AI.class_eval do
      def sidmod_smart_ai?(_idxBattler)
        return false if !SmartAI::ENABLED
        return false if @battle.wildBattle?
        return false if !@battle.trainerBattle?
        return false if @battle.pbSideSize(0) > 1 || @battle.pbSideSize(1) > 1
        true
      end
    end
    @ai_patched = true
  end

  # CRITICAL FAIRNESS FIX. pbSwitchInBetween sends player-owned battlers to
  # pbPartyScreen, and the debug scene's pbPartyScreen picks a RANDOM replacement.
  # So under controlPlayer side 0 got random post-faint switch-ins while side 1 got
  # SmartAI's rated revenge-killer pick — measured at 0/20 vs 11/20 on the same
  # pair of teams. Route both sides through the AI whenever the sim drives both.
  def patch_replacement_symmetry!
    return if @switch_patched
    PokeBattle_Battle.class_eval do
      alias_method :nsim_orig_pbSwitchInBetween, :pbSwitchInBetween
      def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
        if @controlPlayer
          return @battleAI.pbDefaultChooseNewEnemy(idxBattler, pbParty(idxBattler))
        end
        nsim_orig_pbSwitchInBetween(idxBattler, checkLaxOnly, canCancel)
      end
    end
    @switch_patched = true
  end

  # Optional readable log: battle messages + the SmartAI planner's own decision
  # lines (which need $INTERNAL). Only captured when $NSIM_LOG is an Array.
  def patch_logging!
    return if @log_patched
    PokeBattle_Battle.class_eval do
      alias_method :nsim_orig_pbDisplay, :pbDisplay
      def pbDisplay(msg, &block); $NSIM_LOG << msg.to_s if $NSIM_LOG; nsim_orig_pbDisplay(msg, &block); end
      alias_method :nsim_orig_pbDisplayPaused, :pbDisplayPaused
      def pbDisplayPaused(msg, &block); $NSIM_LOG << msg.to_s if $NSIM_LOG; nsim_orig_pbDisplayPaused(msg, &block); end
      alias_method :nsim_orig_pbDisplayBrief, :pbDisplayBrief
      def pbDisplayBrief(msg); $NSIM_LOG << msg.to_s if $NSIM_LOG; nsim_orig_pbDisplayBrief(msg); end
    end
    eval(<<~RUBY, TOPLEVEL_BINDING)
      module PBDebug
        def self.log(msg); $NSIM_LOG << msg.to_s if $NSIM_LOG; end
        def self.logonerr; yield; end
      end
    RUBY
    @log_patched = true
  end

  # KO / faint attribution. lastAttacker is pushed per damaging hit and cleared at
  # end of round, so at faint time its last entry is the killer (nil => chip damage:
  # hazards/status/weather/recoil).
  def patch_faint_tracking!
    return if @faint_patched
    PokeBattle_Battler.class_eval do
      alias_method :nsim_orig_pbFaint, :pbFaint
      def pbFaint(showMessage = true)
        if $NSIM_EVENTS
          killer = (@lastAttacker || []).last
          $NSIM_EVENTS << [:faint, index, (pokemonIndex rescue -1), killer,
                           (killer ? (@battle.battlers[killer].pokemonIndex rescue -1) : -1)]
        end
        nsim_orig_pbFaint(showMessage)
      end
    end
    @faint_patched = true
  end

  # ---- pool ------------------------------------------------------------------
  # Every PC mon at Lv100 holding an item, keyed by box/slot, with the same
  # candidate metadata + clauses the in-game "Random Battle" feature uses.
  def build_pool!
    @pool = []
    $PokemonStorage.maxBoxes.times do |b|
      $PokemonStorage.maxPokemon(b).times do |i|
        pk = $PokemonStorage[b, i]
        next if pk.nil? || (pk.egg? rescue false)
        next unless pk.level == 100 && (pk.hasItem? rescue false)
        c = SidmodRandomOpp.candidate(pk)
        next if (c[:moves] & SidmodRandomOpp::BANNED_MOVES).any?    # Spore clause
        @pool << { key: "b#{b}s#{i}", box: b, slot: i,
                   name: (pk.name || pk.speciesName).to_s,
                   species: (pk.speciesName rescue pk.species.to_s),
                   cand: c, ref: pk,
                   ou: SidmodRandomOpp.ou_legal?(c),
                   roles: SidmodRandomOpp.classify(c),
                   types: c[:types], bases: c[:bases],
                   item: c[:item], moves: c[:moves] }
      end
    end
    @by_key = @pool.each_with_object({}) { |e, h| h[e[:key]] = e }
    @pool
  end

  def pool(tier: :ou)
    tier == :ou ? @pool.select { |e| e[:ou] } : @pool
  end

  def entry(key); @by_key[key]; end
  def all_pool; @pool; end

  def party(keys)
    keys.map do |k|
      e = @by_key[k] or raise "unknown pool key #{k} (save in use: #{save_path_in_use}; " \
                              "pool has #{@pool.length} mons — did the save change mid-run?)"
      pk = Marshal.load(Marshal.dump(e[:ref]))
      pk.heal
      pk
    end
  end

  # Battle two already-built parties (used to test candidate mons that are not in the
  # save yet, so a proposed addition can be measured BEFORE anything is written).
  def run_mons(pa, pb, seed: 1)
    pa = pa.map { |p| c = Marshal.load(Marshal.dump(p)); c.heal; c }
    pb = pb.map { |p| c = Marshal.load(Marshal.dump(p)); c.heal; c }
    $NSIM_EVENTS = []; $NSIM_LOG = nil
    srand(seed)
    t1 = SimBattle.make_trainer('A', pa); t2 = SimBattle.make_trainer('B', pb)
    battle = PokeBattle_Battle.new(PokeBattle_DebugSceneNoLogging.new, t1.party, t2.party, t1, t2)
    battle.debug = true; battle.controlPlayer = true
    battle.internalBattle = false; battle.canRun = false
    dec = nil
    orig = $stdout; $stdout = File.open(File::NULL, 'w')
    begin
      dec = battle.pbStartBattle
    rescue Exception
      dec = 5
    ensure
      $stdout.close; $stdout = orig
    end
    $NSIM_EVENTS = nil
    dec == 1 ? :a : (dec == 2 ? :b : :draw)
  end

  # A pool key -> a fresh Pokemon (same as `party`, for one mon)
  def mon(key)
    e = @by_key[key] or raise "unknown pool key #{key}"
    pk = Marshal.load(Marshal.dump(e[:ref])); pk.heal; pk
  end

  # ---- one battle ------------------------------------------------------------
  # Returns { winner: :a/:b/:draw, turns:, a:[per-mon], b:[per-mon] } where per-mon
  # is { key:, fainted:, hp:, kos:, chip_kos: } indexed like the input key list.
  def run(keysA, keysB, seed: 1, log: false)
    pa = party(keysA); pb = party(keysB)
    $NSIM_EVENTS = []
    $NSIM_LOG = log ? [] : nil
    $INTERNAL = log ? true : nil     # SmartAI prints per-plan scores only when $INTERNAL
    srand(seed)
    t1 = SimBattle.make_trainer("A", pa)
    t2 = SimBattle.make_trainer("B", pb)
    scene  = PokeBattle_DebugSceneNoLogging.new
    battle = PokeBattle_Battle.new(scene, t1.party, t2.party, t1, t2)
    battle.debug = true; battle.controlPlayer = true
    battle.internalBattle = false; battle.canRun = false
    dec = nil
    orig = $stdout; $stdout = File.open(File::NULL, "w")
    begin
      dec = battle.pbStartBattle
    rescue Exception => e
      dec = 5
      @last_error = "#{e.class}: #{e.message.lines.first.to_s.strip[0, 90]}"
    ensure
      $stdout.close; $stdout = orig
    end
    turns  = (battle.turnCount rescue 0)
    events = $NSIM_EVENTS; $NSIM_EVENTS = nil

    stats = ->(keys, side) {
      keys.each_with_index.map { |k, i| { key: k, fainted: false, hp: 1.0, kos: 0, chip: 0, side: side, idx: i } }
    }
    sa = stats.(keysA, 0); sb = stats.(keysB, 1)
    # final HP fractions from the live parties
    [[pa, sa], [pb, sb]].each do |arr, st|
      arr.each_with_index do |pk, i|
        next if !st[i]
        st[i][:hp] = pk.totalhp > 0 ? (pk.hp.to_f / pk.totalhp) : 0.0
        st[i][:fainted] = (pk.hp <= 0)
      end
    end
    # faint events -> KO credit
    events.each do |(_tag, bidx, pidx, killer, kpidx)|
      side = (bidx % 2)   # side 0 = A, side 1 = B in singles
      st   = side == 0 ? sa : sb
      st[pidx][:fainted] = true if st[pidx]
      if killer && kpidx && kpidx >= 0
        kst = (killer % 2) == 0 ? sa : sb
        kst[kpidx][:kos] += 1 if kst[kpidx]
      else
        oth = side == 0 ? sb : sa
        oth.each { |m| m[:chip] += 0 }   # unattributed (hazards/status): counted at team level
      end
    end
    winner = dec == 1 ? :a : (dec == 2 ? :b : :draw)
    lines = $NSIM_LOG; $NSIM_LOG = nil; $INTERNAL = nil
    { winner: winner, decision: dec, turns: turns, a: sa, b: sb,
      a_alive: sa.count { |m| !m[:fainted] }, b_alive: sb.count { |m| !m[:fainted] },
      log: lines }
  end

  # ---- readable set dump (for eyeballing "do these teams look sane?") --------
  STATS6 = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED]
  SHORT  = { HP: 'HP', ATTACK: 'Atk', DEFENSE: 'Def', SPECIAL_ATTACK: 'SpA',
             SPECIAL_DEFENSE: 'SpD', SPEED: 'Spe' }
  def describe(key)
    e = @by_key[key]; pk = e[:ref]
    evs = STATS6.map { |s| v = (pk.ev[s] rescue 0); v > 0 ? "#{SHORT[s]}#{v}" : nil }.compact.join('/')
    st  = STATS6.map { |s| (pk.calcStats && pk.calcStats[s]) rescue nil }
    st  = STATS6.map { |s| (pk.send(s == :HP ? :totalhp : { ATTACK: :attack, DEFENSE: :defense,
          SPECIAL_ATTACK: :spatk, SPECIAL_DEFENSE: :spdef, SPEED: :speed }[s]) rescue 0) } if st.compact.empty?
    { key: key, name: e[:name], species: e[:species], box: e[:box] + 1, slot: e[:slot] + 1,
      types: e[:types].join('/'), ability: (pk.ability&.name rescue '?'),
      nature: (pk.nature&.name rescue '?'), item: (pk.item&.name rescue e[:item].to_s),
      moves: e[:moves].map { |m| (GameData::Move.get(m).name rescue m.to_s) },
      evs: evs, stats: st, roles: e[:roles].join(','), ou: e[:ou] }
  end

  def show_team(keys, label = nil)
    out = []
    out << "#{label}" if label
    keys.each do |k|
      d = describe(k)
      out << "  %-14s %-26s %-13s | %s | %s | %s" % [d[:name], d[:species][0, 26], d[:types],
                                                     d[:ability][0, 14], d[:item][0, 14], d[:moves].join('/')]
      out << "      stats #{d[:stats].join('/')}  evs #{d[:evs]}  nature #{d[:nature]}  roles #{d[:roles]}  [Box#{d[:box]} slot#{d[:slot]}]"
    end
    out.join("\n")
  end

  def last_error; @last_error; end
end
