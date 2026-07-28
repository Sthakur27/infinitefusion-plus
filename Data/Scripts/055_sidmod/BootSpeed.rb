#===============================================================================
# sidmod: Boot speed - stop re-downloading the custom Pokedex on every launch
#
# THE PROBLEM
# pbStartLoadScreen (052_InfiniteFusion/System/MultiSaves.rb ~line 531) calls
# updateHttpSettingsFile then updateCustomDexFile before the load screen can draw.
# updateCustomDexFile pulls Settings::CUSTOM_DEX_FILE_URL into
# Settings::CUSTOM_DEX_ENTRIES_PATH ("Data/pokedex/dex.json") - a ~19 MB file -
# with a SYNCHRONOUS HTTPLite.get on the main thread. Unconditionally. Every boot.
# So every launch stalls for as long as that download takes, and an interrupted
# write is what produced the Errno::EINVAL boot crash (rb_sysopen on dex.json).
# Confirmed by watching dex.json's mtime move on each launch.
#
# THE FIX
# Skip the download while the local copy is still fresh. New custom dex entries
# still arrive (once a day by default), boot is instant the rest of the time, and
# the interrupted-write crash window shrinks from "every launch" to "once a day".
#
# WHY NOT JUST TURN DOWNLOADS OFF
# downloadAllowed? is `$PokemonSystem.download_sprites == 0`, i.e. the one Options
# toggle also governs custom fusion sprite fetching - switching it off to fix boot
# time would silently cost you fusion art. This targets only the dex.
#
# 055_ loads after 052_, so this definition wins. To revert: delete this file.
#===============================================================================

module SidmodBoot
  # How long a local dex.json is considered current. Set to 0 to always download
  # (stock behaviour), or something large to effectively pin the local copy.
  DEX_MAX_AGE = 24 * 60 * 60   # seconds

  module_function

  def dex_age
    path = Settings::CUSTOM_DEX_ENTRIES_PATH
    return nil if !File.exist?(path)
    Time.now - File.mtime(path)
  rescue
    nil
  end

  def dex_fresh?
    age = dex_age
    !age.nil? && age >= 0 && age < DEX_MAX_AGE
  end
end

# Replaces 052_InfiniteFusion/System/HttpCalls.rb ~line 20. Same behaviour, plus the
# freshness check. Kept structurally identical to the original so a future upstream
# change to it is easy to spot.
def updateCustomDexFile
  return if !downloadAllowed?()
  if SidmodBoot.dex_fresh?
    echoln "sidmod: custom dex is #{(SidmodBoot.dex_age / 3600.0).round(1)}h old, skipping download"
    return
  end
  download_file(Settings::CUSTOM_DEX_FILE_URL, Settings::CUSTOM_DEX_ENTRIES_PATH,)
end
