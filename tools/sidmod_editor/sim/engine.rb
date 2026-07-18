# Reusable headless boot of the real IF engine. `require_relative 'engine'` then
# SimEngine.boot. Read-only on game files; save_data is neutered in shim.rb.
# Must be run with CWD = game root (C:\Games\InfiniteFusion).
require_relative 'shim'
require_relative '../stub_loader'
require 'zlib'

module SimEngine
  module_function

  IGNORED = ['.', '..', '.git', '.idea', '.gitignore']

  def load_folder(path)
    files = []; folders = []
    Dir.foreach(path) do |f|
      next if IGNORED.include?(f)
      File.directory?("#{path}/#{f}") ? folders.push(f) : files.push(f)
    end
    files.sort.each do |f|
      begin
        eval(File.read("#{path}/#{f}"), TOPLEVEL_BINDING, f)
      rescue Exception => e
        @skipped << ["#{path}/#{f}", "#{e.class}: #{e.message.lines.first.to_s.strip}"]
      end
    end
    folders.sort.each { |d| load_folder("#{path}/#{d}") }
  end

  def boot(verbose: false)
    return if @booted
    $VERBOSE = nil
    @skipped = []
    scripts = StubLoader.load_file("Data/Scripts.rxdata")
    gs = scripts.find { |e| e[1].to_s == 'GameSettings' }
    eval(Zlib::Inflate.inflate(gs[2]), TOPLEVEL_BINDING, 'GameSettings') if gs
    load_folder("Data/Scripts")
    GameData.load_all
    patch_runtime
    setup_globals
    @booted = true
    warn "[SimEngine] booted; #{@skipped.length} scripts skipped" if verbose
    self
  end

  # Redefine engine helpers that assume a live game session to headless-safe
  # versions. Applied after the engine loads (so our defs win) and before we
  # build $Trainer (which calls some of them).
  def patch_runtime
    eval(<<~RUBY, TOPLEVEL_BINDING)
      def pbGetLanguage; 2; end          # English; avoids $PokemonSystem.language nil deref
      def pbGetUserName; "USER"; end     # avoids nil in the exception logger
      module PBDebug
        def self.logonerr; yield; end    # headless: let real exceptions surface, don't swallow
      end
      class PokeBattle_DebugSceneNoLogging
        # catch-all no-op for any animation/display method this IF build calls that
        # the stock stub doesn't implement (return-value methods are already defined).
        def method_missing(*); nil; end
        def respond_to_missing?(*); true; end
      end
    RUBY
  end

  # Minimal globals for Pokemon.new / battles. Each guarded so a missing class
  # doesn't abort the boot.
  def setup_globals
    g = ->(expr) { begin; expr.call; rescue Exception; nil; end }
    $game_temp          = g.(-> { Game_Temp.new })
    $game_system        = g.(-> { Game_System.new })
    $game_switches      = g.(-> { Game_Switches.new })
    $game_variables     = g.(-> { Game_Variables.new })
    $game_self_switches = g.(-> { Game_SelfSwitches.new })
    $PokemonSystem      = g.(-> { PokemonSystem.new })
    $PokemonGlobal      = g.(-> { PokemonGlobalMetadata.new })
    $PokemonBag         = g.(-> { PokemonBag.new })
    # A valid trainer type + a default $Trainer so Pokemon.new has an owner.
    @ttype = g.(-> { GameData::TrainerType.each { |t| break t.id } })
    $Trainer = g.(-> { NPCTrainer.new("Sim", @ttype) })
  end

  def trainer_type; @ttype; end

  def skipped; @skipped; end
end
