# Coach-with-a-build-check-loop. Opus proposes fixes for a team, but instead of hallucinating
# fusion typings/stats it CALLS the fusion inspector (real engine) on each candidate, reads the
# actual typing / stats-vs-parents / weaknesses / auto-flags, and revises until it's satisfied.
# This is the "try out a suggestion, see the result, decide to proceed or think more" loop.
#
# Usage: ruby tools/sidmod_editor/sim/coach_loop.rb <team> [<team> ...]
#   reads  reports/final/field_specs.json  (+ reports/final_audit/<team>.txt if present)
#   writes reports/final_v2/field_specs.json  (only the processed teams; originals untouched)
require 'json'; require 'fileutils'
SRC   = File.join(__dir__, 'reports', 'final_v2', 'field_specs.json')   # CURRENT teams
FIELD = JSON.parse(File.read(SRC))                     # parse BEFORE boot (engine breaks JSON)
# Static reservations to fix AGGRESSIVELY (net-benefit bar). Fed as the coach's analysis input.
AUDIT = {
  "OUBalance" => "Static reservation: NO dedicated special wall - the team distributes special bulk but nothing hard-walls a strong special attacker. Gliscor/Suicune is 4x Grass (borderline). NOTE: swapping a defensive slot for a special/Unaware wall previously regressed physical matchups by shedding physical bulk - so any special answer must NOT gut the team's physical bulk. Keep both wincons (Dragonite/Scizor Multiscale DD; Marowak/Mimikyu Disguise + Thick Club breaker with Shadow Sneak priority) and the ONLY hazard control (Starmie/Tentacruel Rapid Spin). Be aggressive only if it nets clear benefit without opening a bigger hole.",
  "OURain"    => "Static reservations: WATER-STACKED (4 Waters) so one bulky Water-Absorb/Storm-Drain or Grass wall neutralizes the core; SINGLE Drizzle setter (Politoed/Whimsicott) = single point of failure (if it faints, 3 Swift Swimmers lose half their Speed); no special wall; Grass-weakness stacked. Aggressively reduce redundancy among the 3 Swift Swimmers (Kingdra/Empoleon, Poliwrath/Swampert, Ludicolo/Sceptile) and/or add coverage/insurance so Grass/Electric/fat-Water walls can't wall the whole team. KEEP the rain identity + Dragonite/Scizor (rain-independent DD wincon) + Ferrothorn/Skarmory hazards.",
  "OUSun"     => "Static reservation: THREE Fire-typed mons (Venusaur/Chandelure, Charizard/Hydreigon, Leafeon/Arcanine) = stacked 2x Stealth Rock weakness + overlapping checks (Water/Rock/Ground hit multiple at once). Leafeon/Arcanine is the MOST redundant sweeper. The team also has NO Stealth Rock setter. Aggressively replace Leafeon/Arcanine with a NON-Fire threat that diversifies typing (ideally Stealth-Rock-neutral) and covers a team need (hazards, or an answer to opposing rain that overwrites Drought). KEEP Ninetales/Whimsicott (Drought+Spore), Regigigas/Gliscor (weather-INDEPENDENT Poison Heal wincon), Blissey/Shuckle (special wall + Sticky Web + Rapid Spin).",
  "OUSand"    => "Static reservations: Rhyperior/Salamence is 4x ICE (the team's biggest liability); the SAND does NO offensive work (no Sand Rush abuser - it's balance-with-sand); double Stealth Rock (Tyranitar/Aerodactyl + Ferrothorn/Skarmory) is redundant. Aggressive ideas: add a SAND RUSH abuser so the weather actually matters offensively, OR re-fuse Rhyperior/Salamence to cut the 4x Ice while keeping band-breaker power. KEEP Metagross/Garchomp (Steel/Ground Scarf, resists Ice) and Dragonite/Scizor (Multiscale DD wincon).",
  "Ubers1"    => "Static reservation: Kyurem/Metagross (Dragon/Psychic) is the WEAKEST slot - six 2x-weaknesses, weak revenge, choice-locked. Prior KYUREM re-fuses all failed (they bring back 4x Ice), so REPLACE KYUREM ENTIRELY with a better Ubers Choice-Scarf revenge-killer OR a phazer/anti-setup (the team LACKS phazing). Also Ice-weakness is stacked (Groudon/Gliscor 4x Ice). KEEP the excellent fusions: Kyogre/Mew (Drizzle+Spore+Water Spout), Slaking/Dragonite (Multiscale ExtremeSpeed, no Truant), Dialga/Espeon (Magic Bounce), Darkrai/Hydreigon (Nasty Plot breaker), Groudon/Gliscor (Poison Heal SD).",
  "Ubers2"    => "Static reservations: Palkia/Flygon's typing == mono Palkia (thinnest justification - carried only by Levitate + Draco Meteor; near-dilution); WATER-stacked (Kyogre/Celebi, Kingdra/Zekrom, Palkia/Flygon = 3 Waters). Aggressively re-fuse the Palkia slot to GAIN a real type (or replace with a special breaker that diversifies the team's typing) while keeping a rain abuser / breaker role. KEEP the spine: Aegislash/Lugia (Multiscale, Spectral Thief steals boosts + Whirlwind phaze), Registeel/Ferrothorn (Steel/Grass hazards), Groudon/Gliscor (Poison Heal SD), Kyogre/Celebi (Drizzle).",
}
require_relative 'fusion_inspector'
require_relative 'claude_client'
require_relative 'editor'
SimEngine.boot
$DEBUG = false

TOOLS = [{
  "name" => "build_fusion",
  "description" => "Build ONE candidate fusion in the real Infinite Fusion engine and return its ACTUAL typing, "\
    "stats (compared to BOTH parents so you can see the fusion tax), 4x/2x weaknesses, resolved ability, and "\
    "auto-flags (TYPING-NO-GAIN = typing identical to a parent so the fusion adds nothing defensively; "\
    "STAT-TAX = key attacking stat far below the better parent; NEW-4x-WEAK / 4x-WEAK; DEAD-ABILITY = ability "\
    "does nothing given the moves/item; ABILITY-NEEDS-ORB; WEATHER-ABILITY; OFF-PARENT-ABILITY; INVALID). "\
    "Call this on EVERY candidate before you commit it. Iterate: if it flags dilution/dead-ability, try another pairing.",
  "input_schema" => {
    "type" => "object",
    "properties" => {
      "head"    => { "type" => "string", "description" => "head base species (governs HP/SpA/SpD + type1), e.g. KYUREM" },
      "body"    => { "type" => "string", "description" => "body base species (governs Atk/Def/Spe + type2), e.g. METAGROSS" },
      "species" => { "type" => "string", "description" => "for a NON-fusion, the single species instead of head/body" },
      "ability" => { "type" => "string" }, "item" => { "type" => "string" }, "nature" => { "type" => "string" },
      "moves"   => { "type" => "array", "items" => { "type" => "string" }, "description" => "4 move constants" }
    }
  }
}]

SYSTEM = <<~SYS
  You are an elite competitive Pokemon Infinite Fusion team builder. You have a build_fusion tool
  that runs the REAL engine and reports STRUCTURAL truth about a candidate: its actual typing,
  stats vs BOTH parents, 4x/2x weaknesses, resolved ability, and auto-flags.

  Fusion mechanics: head gives HP/SpA/SpD + type1; body gives Atk/Def/Spe + type2; each stat is a
  weighted average (2*dominant+other)/3, so fusing TAXES the stronger parent. A fusion earns its
  slot only if each parent contributes something the other lacks - a TYPE, an ABILITY, a MOVE, or a
  stat the other is missing - or it augments a base mon (e.g. Multiscale, Poison Heal, a coverage
  move, a resistance). If the typing equals a parent's and stats are merely taxed with no functional
  gain, that is DILUTION.

  CRITICAL - HOW TO READ THE TOOL'S FLAGS. The flags (TYPING-NO-GAIN, STAT-TAX, DEAD-ABILITY,
  NEW-4x-WEAK, WEATHER-ABILITY, etc.) are DIAGNOSTIC QUESTIONS, NOT ORDERS. Each flag means "look
  at this - does it actually matter for THIS mon's job on THIS team?" It is correct and expected to
  KEEP a flagged mon and explain why the flag is irrelevant. Examples:
    - "TYPING-NO-GAIN vs Skarmory" on Ferrothorn/Skarmory is FINE - the point is Iron Barbs +
      Leech Seed + extra bulk, not a new type.
    - "DEAD-ABILITY: Rock Head, no recoil move" IS real - either add a recoil STAB or change ability.
    - "STAT-TAX SPA" on a purely physical set is irrelevant.
  Never change a mon just to make a flag disappear. Only change it if the change makes the TEAM better.

  THE TOOL CANNOT SEE MOVE/ABILITY UTILITY OR TEAM ROLE - YOU MUST. This is where your own expertise
  is the whole point. A move with no STAB and low damage can be the single most valuable slot on the
  team. Before you ever remove a move, ask what ROLE it plays and what replaces that role:
    - Anti-setup / disruption: Spectral Thief (STEALS the foe's stat boosts - elite vs setup sweepers),
      Haze, Clear Smog, Roar/Whirlwind/Dragon Tail (phazing), Encore, Taunt, Disable, Destiny Bond.
    - Speed control: Choice Scarf, priority (Extreme Speed/Bullet Punch/Aqua Jet/Mach Punch/Sucker
      Punch/Ice Shard), Sticky Web, Thunder Wave, Tailwind.
    - Hazards: Stealth Rock, Spikes, Toxic Spikes, Sticky Web. Hazard control: Rapid Spin, Defog.
    - Momentum: Volt Switch, U-turn, Flip Turn, Parting Shot, Teleport.
    - Support/sustain: Wish, Healing Wish, Aromatherapy/Heal Bell, Roost/Recover/Slack Off, Leech Seed.
    - Wearing down walls: Toxic, Will-o-Wisp, Knock Off (removes items), Trick/Switcheroo.
  If you remove any such move, you MUST name what now fills that role, or you have made the team worse.

  TEAM-LEVEL CHECKLIST - never open a hole bigger than the one you close. Before finalizing, confirm
  the team still has: a clear WIN CONDITION (never strip the wincon for a generic wall), speed control,
  hazard setting, hazard control, weather setter+abuser synergy if it's a weather team, revenge
  killing, phazing/anti-setup, wallbreaking, status/chip, a defensive backbone, and no stacked shared
  weakness across the core. Every fix must FIT the archetype (a rain team's fix synergizes with rain;
  a momentum team keeps its pivots).

  RIGOROUS PER-CANDIDATE ANALYSIS (required for every mon you propose OR keep) - build_fusion it and
  answer ALL of these explicitly; a candidate is only justified if it clears every one:
    a. TYPING: what is the resulting type? What does it GAIN (new resist/immunity/STAB) and LOSE
       versus EACH parent's typing? Any new 4x weakness?
    b. BASE STATS vs BOTH PARENTS: cite the fusion's key stats next to each parent's (the tool gives
       this). Name the "fusion tax" - which stats dropped and by how much - and whether the taxed
       stats matter for this mon's job.
    c. BETTER-THAN-VANILLA-PARENT TEST: would you rather just run one of the mono parents here? The
       fusion earns its slot ONLY if it does something NEITHER parent can alone - a needed TYPE, an
       ABILITY the other lacks, a combined MOVEPOOL, an ITEM synergy (e.g. Thick Club on a Marowak
       fusion), or a stat one parent is missing. If it's "a worse mono X with a slightly different
       type," it is DILUTION - reject it and say so.
    d. ROLE + SYNERGY: what job does it do on THIS team, and does it fit the archetype without opening
       a hole the checklist above cares about?

  PROCESS:
    1. First, in your thinking, state the team's identity + win condition and map which ROLE each of
       the 6 current mons fills. You cannot judge a change without knowing the role it must preserve.
    2. For a candidate: form a hypothesis -> build_fusion it -> run the RIGOROUS PER-CANDIDATE ANALYSIS
       (a-d) -> compare to what it replaces on ALL axes. Keep it ONLY if it passes (a-d) AND is
       strictly better for the TEAM than the current mon.
    3. Changing ZERO slots is a valid, strong answer. Prefer 1-3 minimal, high-confidence changes over
       churn. When in doubt, keep the mon and justify it.
  Enforce SPECIES CLAUSE: the 6 fusions use DISTINCT base species (no species as head/body on two
  mons). Every mon L100, 4 valid moves, valid ability/item/nature. Weather from an ability is permanent.

  When DONE, output the FINAL 6-mon team as a JSON array in a fenced block:
  ```json
  [ {"head":"X","body":"Y","ability":"A","item":"I","nature":"N","moves":["M1","M2","M3","M4"],
     "evs":{"HP":n,"ATTACK":n,"DEFENSE":n,"SPECIAL_ATTACK":n,"SPECIAL_DEFENSE":n,"SPEED":n}}, ... ]
  ```
  Precede it with a CHANGELOG. For EVERY slot (changed or kept), give the RIGOROUS PER-CANDIDATE
  ANALYSIS in compact form: "slot N: NAME - TYPING (gain/loss vs parents) | STATS vs parents (the
  tax) | better-than-mono? (why it's not dilution) | ROLE". For a CHANGED slot also state OLD -> NEW
  and, if a utility move was dropped, name its replacement. This is the proof each fusion earns its
  slot - no hand-waving.
SYS

def spec_to_json(team)
  team.map do |m|
    s = Editor.normalize(m)
    o = {}
    o["head"] = s[:head].to_s if s[:head]; o["body"] = s[:body].to_s if s[:body]
    o["species"] = s[:species].to_s if s[:species] && !s[:head]
    o["ability"] = s[:ability].to_s; o["item"] = s[:item].to_s; o["nature"] = s[:nature].to_s
    o["moves"] = (s[:moves] || []).map(&:to_s)
    o
  end
end

def run_team(team_name)
  team = FIELD[team_name] or (warn "no team #{team_name}"; return nil)
  audit = AUDIT[team_name].to_s
  user = +"TEAM: #{team_name}\n\nCURRENT ROSTER (JSON):\n#{ClaudeClient::GEN.call(spec_to_json(team))}\n\n"
  user << "STATIC RESERVATIONS TO FIX AGGRESSIVELY (net-benefit bar - change freely if it clearly improves the team):\n#{audit[0, 6000]}\n\n" unless audit.empty?
  user << "This is a PURE-STATIC pass (no battles). Use build_fusion to verify every candidate against the real "\
          "engine. Be AGGRESSIVE: reshape any slot - including replacing a species entirely - as long as it NETS a "\
          "clear structural benefit (better typing/role/synergy, closes the reservation) WITHOUT opening a bigger "\
          "hole or violating Species Clause. Run the RIGOROUS PER-CANDIDATE ANALYSIS on every proposal. Then output the final team."

  calls = 0
  model = ENV['COACH_MODEL'] || "claude-opus-4-8"   # thinking model; set COACH_MODEL=claude-sonnet-5 to switch
  text, msgs = ClaudeClient.complete_tools(system: SYSTEM, user: user, tools: TOOLS, model: model,
                                           max_tokens: 20000, max_rounds: 40, thinking_budget: 12000) do |name, input|
    next "unknown tool #{name}" unless name == "build_fusion"
    calls += 1
    r = Inspect.check(input)
    rendered = Inspect.render(r)
    puts "  [#{team_name} build_fusion ##{calls}] #{input['head']}#{input['body'] ? "/#{input['body']}" : ''}#{input['species']}"
    rendered
  end
  if ENV['SHOW_THINKING']
    think = msgs.flat_map { |m| Array(m[:content]) }.select { |b| b.is_a?(Hash) && b["type"] == "thinking" }
                .map { |b| b["thinking"] }.join("\n---\n")
    puts "\n----- #{team_name} THINKING -----\n#{think}\n" unless think.empty?
  end
  puts "\n===== #{team_name}: coach made #{calls} build-checks =====\n#{text}\n"

  # extract final JSON array
  m = text[/```json\s*(\[.*?\])\s*```/m] ? $1 : text[/\[\s*\{.*\}\s*\]/m]
  arr = (ClaudeClient.json_parse(m) rescue nil)
  unless arr.is_a?(Array) && arr.size == 6
    warn "  !! #{team_name}: could not parse final 6-mon array (kept original)"; return spec_to_json(team)
  end
  # validate every mon; revert any invalid slot to the original
  final = arr.each_with_index.map do |mon, i|
    r = Inspect.check(mon)
    if r[:ok] then mon
    else warn "  !! #{team_name} slot #{i} invalid (#{r[:flags].join('; ')}) -> reverted"; spec_to_json(team)[i]
    end
  end
  final
end

TARGETS = ARGV.empty? ? FIELD.keys.reject { |k| %w[OU UbersOff UbersBal].include?(k) } : ARGV
out = {}
TARGETS.each { |t| r = run_team(t); out[t] = r if r }
DST = File.join(__dir__, 'reports', 'final_v3'); FileUtils.mkdir_p(DST)   # proposals - does NOT touch current teams
File.write(File.join(DST, 'field_specs.json'), JSON.generate(out))
puts "wrote #{out.size} revised teams -> reports/final_v3/field_specs.json"
