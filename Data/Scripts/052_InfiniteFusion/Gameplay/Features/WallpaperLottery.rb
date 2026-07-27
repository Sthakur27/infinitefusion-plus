class PokemonStorage
  def wallpaperLottery
    cmd_play = _INTL("Play!")
    cmd_info = _INTL("Info")
    cmd_cancel = _INTL("Cancel")
    commands = [cmd_play, cmd_info, cmd_cancel]

    choice = pbMessage(_INTL("Would you like to play the Wallpaper Lottery? (\\C[1]Free\\C[0])"),commands,2)

    case commands[choice]
    when cmd_play
      locked_wallpapers = []
      for i in BASICWALLPAPERQTY..allWallpapers.length-1
        locked_wallpapers << i unless isAvailableWallpaper?(i)
      end
      if locked_wallpapers.empty?
        pbMessage(_INTL("You don't have any wallpapers left to unlock!"))
        return
      end

      unlocked_index = locked_wallpapers.sample

      $game_system.bgm_memorize
      $game_system.bgm_stop

      pbWait(8)
      pbSEPlay("BW_exp")
      pbWait(90)
      $game_system.bgm_restore
      obtain_wallpaper(unlocked_index)
    when cmd_info
      pbMessage(_INTL("The Wallpaper Lottery allows you to unlock \\C[1]new wallpapers\\C[0] for your PC boxes background."))
      pbMessage(_INTL("Participating in the lottery is \\C[1]free\\C[0]!"))

    end
  end

  def obtain_wallpaper(wallpaper_id)
    wallpaper_name = allWallpapers[wallpaper_id]
    pbUnlockWallpaper(wallpaper_id)
    path = "Graphics/Pictures/Storage/Wallpapers/box_#{wallpaper_id}"
    pictureViewport = showPicture(path, 50,-45)
    musical_effect = "Key item get"
    pbMessage(_INTL("\\qp\\me[{1}]Obtained a new wallpaper: \\c[1]{2}\\c[0]!", musical_effect, wallpaper_name))
    pictureViewport.dispose if pictureViewport
  end
end

class WallpaperLotteryPC
  def shouldShow?
    return player_has_quest_journal?
  end

  def name
    return _INTL("Wallpaper Lottery")
  end

  def access
    pbMessage(_INTL("\\se[PC access]Accessed the Wallpaper Lottery."))
    $PokemonStorage.wallpaperLottery
  end
end

#===============================================================================
#
#===============================================================================
PokemonPCList.registerPC(WallpaperLotteryPC.new)