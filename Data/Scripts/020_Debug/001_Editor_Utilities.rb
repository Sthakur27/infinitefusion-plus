def pbGetLegalMoves(species)
  species_data = GameData::Species.get(species)
  moves = []
  return moves if !species_data
  species_data.moves.each { |m| moves.push(m[1]) }
  species_data.tutor_moves.each { |m| moves.push(m) }
  babyspecies = species_data.get_baby_species
  GameData::Species.get(babyspecies).egg_moves.each { |m| moves.push(m) }
  moves |= []   # Remove duplicates
  return moves
end

def pbSafeCopyFile(x,y,z=nil)
  if safeExists?(x)
    safetocopy = true
    filedata = nil
    if safeExists?(y)
      different = false
      if FileTest.size(x)!=FileTest.size(y)
        different = true
      else
        filedata2 = ""
        File.open(x,"rb") { |f| filedata  = f.read }
        File.open(y,"rb") { |f| filedata2 = f.read }
        different = true if filedata!=filedata2
      end
      if different
        safetocopy=pbConfirmMessage(_INTL("A different file named '{1}' already exists. Overwrite it?",y))
      else
        # No need to copy
        return
      end
    end
    if safetocopy
      if !filedata
        File.open(x,"rb") { |f| filedata = f.read }
      end
      File.open((z) ? z : y,"wb") { |f| f.write(filedata) }
    end
  end
end

def pbAllocateAnimation(animations,name)
  for i in 1...animations.length
    anim = animations[i]
    return i if !anim
#    if name && name!="" && anim.name==name
#      # use animation with same name
#      return i
#    end
    if anim.length==1 && anim[0].length==2 && anim.name==""
      # assume empty
      return i
    end
  end
  oldlength = animations.length
  animations.resize(10)
  return oldlength
end

def pbMapTree
  mapinfos = pbLoadMapInfos
  maplevels = []
  retarray = []
  for i in mapinfos.keys
    info = mapinfos[i]
    level = -1
    while info
      info = mapinfos[info.parent_id]
      level += 1
    end
    if level>=0
      info = mapinfos[i]
      maplevels.push([i,level,info.parent_id,info.order])
    end
  end
  maplevels.sort! { |a,b|
    next a[1]<=>b[1] if a[1]!=b[1] # level
    next a[2]<=>b[2] if a[2]!=b[2] # parent ID
    next a[3]<=>b[3] # order
  }
  stack = []
  stack.push(0,0)
  while stack.length>0
    parent = stack[stack.length-1]
    index = stack[stack.length-2]
    if index>=maplevels.length
      stack.pop
      stack.pop
      next
    end
    maplevel = maplevels[index]
    stack[stack.length-2] += 1
    if maplevel[2]!=parent
      stack.pop
      stack.pop
      next
    end
    retarray.push([maplevel[0],mapinfos[maplevel[0]].name,maplevel[1]])
    for i in index+1...maplevels.length
      if maplevels[i][2]==maplevel[0]
        stack.push(i)
        stack.push(maplevel[0])
        break
      end
    end
  end
  return retarray
end

#===============================================================================
# List all members of a class
#===============================================================================
# Displays a list of all Pokémon species, and returns the ID of the species
# selected (or nil if the selection was canceled). "default", if specified, is
# the ID of the species to initially select. Pressing Input::ACTION will toggle
# the list sorting between numerical and alphabetical.
def pbChooseSpeciesList(default = nil,max=nil)
  # commands = []
  # GameData::Species.each { |s| commands.push([s.id_number, s.real_name, s.id]) if s.form == 0 }
  # return pbChooseList(commands, default, nil, -1)
  #
  defaultNumber = default == nil ? 1 : getDexNumberForSpecies(default)
  params = ChooseNumberParams.new

  max = max ? max : PBSpecies.maxValue
  params.setRange(1,max)
  params.setInitialValue(defaultNumber)
  dexNum = pbMessageChooseNumber("dex number?",params)
  return GameData::Species.get(dexNum)
end

def pbChooseSpeciesTextList(default = nil)
  commands = []
  for i in 1..NB_POKEMON
    species = GameData::Species.get(i)
    commands.push([species.id_number, species.real_name, species.id])
  end
  return pbChooseList(commands, default, nil, -1)
end


def pbChooseSpeciesFormList(default = nil)
  commands = []
  GameData::Species.each do |s|
    name = (s.form == 0) ? s.real_name : sprintf("%s_%d", s.real_name, s.form)
    commands.push([s.id_number, name, s.id])
  end
  return pbChooseList(commands, default, nil, -1)
end

# Displays a list of all moves, and returns the ID of the move selected (or nil
# if the selection was canceled). "default", if specified, is the ID of the move
# to initially select. Pressing Input::ACTION will toggle the list sorting
# between numerical and alphabetical.
def pbChooseMoveList(default = nil)
  commands = []
  GameData::Move.each { |i| commands.push([i.id_number, i.real_name, i.id]) }
  return pbChooseList(commands, default, nil, 1)
end

def pbChooseMoveListForSpecies(species, defaultMoveID = nil)
  cmdwin = pbListWindow([], 200)
  commands = []
  # Get all legal moves
  legalMoves = pbGetLegalMoves(species)
  legalMoves.each do |move|
    move_data = GameData::Move.get(move)
    commands.push([move_data.id_number, move_data.name, move_data.id])
  end
  commands.sort! { |a, b| a[1] <=> b[1] }
  moveDefault = 0
  if defaultMoveID
    commands.each_with_index do |_item, i|
      moveDefault = i if moveDefault == 0 && i[2] == defaultMoveID
    end
  end
  # Get all moves
  commands2 = []
  GameData::Move.each do |move_data|
    commands2.push([move_data.id_number, move_data.name, move_data.id])
  end
  commands2.sort! { |a, b| a[1] <=> b[1] }
  if defaultMoveID
    commands2.each_with_index do |_item, i|
      moveDefault = i if moveDefault == 0 && i[2] == defaultMoveID
    end
  end
  # Choose from all moves
  commands.concat(commands2)
  realcommands = []
  commands.each { |cmd| realcommands.push(cmd[1]) }
  ret = pbCommands2(cmdwin, realcommands, -1, moveDefault, true)
  cmdwin.dispose
  return (ret >= 0) ? commands[ret][2] : nil
end

# Displays a list of all types, and returns the ID of the type selected (or nil
# if the selection was canceled). "default", if specified, is the ID of the type
# to initially select. Pressing Input::ACTION will toggle the list sorting
# between numerical and alphabetical.
def pbChooseTypeList(default = nil)
  commands = []
  GameData::Type.each { |t| commands.push([t.id_number, t.name, t.id]) if !t.pseudo_type }
  return pbChooseList(commands, default, nil, -1)
end

# Displays a list of all items, and returns the ID of the item selected (or nil
# if the selection was canceled). "default", if specified, is the ID of the item
# to initially select.
# sidmod: now alphabetical with a live type-to-search box (was pbChooseList with
# sortType -1, i.e. ID-ordered with an ACTION toggle for alphabetical).
def pbChooseItemList(default = nil)
  commands = []
  GameData::Item.each { |i| commands.push([i.id_number, i.name, i.id]) }
  return pbChooseListSearchable(commands, default, _INTL("item"))
#  return pbChooseList(commands, default, nil, -1)   # sidmod: old behaviour
end

# sidmod: alphabetically-sorted list picker with a live search box.
# "commands" is an array of [id_number, display name, id symbol]; returns the id
# symbol (or id number) of the entry chosen, or nil if cancelled.
# Keyboard only: type to filter, UP/DOWN (HOME/END for top/bottom) to move, ENTER
# to choose, ESC to cancel. Gamepad buttons are ignored on purpose - while text
# input is on, the letter keys bound to USE/BACK would fire while typing.
def pbChooseListSearchable(commands, default = nil, what = _INTL("entry"))
  entries = commands.sort { |a, b| a[1].downcase <=> b[1].downcase }
  searchwin = Window_TextEntry_Keyboard.new("", 0, 0, Graphics.width / 2, 96,
                                            _INTL("Search {1}:", what), true)
  searchwin.maxlength = 20
  searchwin.z = 99999
  searchwin.active = true
  cmdwin = Window_CommandPokemon.newWithSize([], 0, 96, Graphics.width / 2,
                                             Graphics.height - 96)
  cmdwin.ignore_input = true   # navigated below; LEFT/RIGHT belong to the search box
  cmdwin.rowHeight = 24
  pbSetSmallFont(cmdwin.contents)
  cmdwin.z = 99999
  cmdwin.active = true
  helpwin = Window_UnformattedTextPokemon.newWithSize("", Graphics.width / 2,
                                                      Graphics.height - 192,
                                                      Graphics.width / 2, 192)
  helpwin.letterbyletter = false
  helpwin.z = 99999
  filtered = []
  oldtext = nil
  ret = nil
  Input.text_input = true
  loop do
    if oldtext != searchwin.text   # Rebuild the filtered list
      oldtext = searchwin.text
      query = oldtext.downcase.strip
      filtered = entries.select do |e|
        query == "" || e[1].downcase.include?(query) || e[2].to_s.downcase.include?(query)
      end
      cmdwin.commands = filtered.map { |e| sprintf("%s (%03d)", e[1], e[0]) }
      index = 0
      if default
        filtered.each_with_index { |e, i| index = i if e[2] == default || e[0] == default }
      end
      cmdwin.index = index
      helpwin.text = _INTL("Type to search.\nUP/DOWN: move (HOME/END: ends)\nENTER: choose, ESC: cancel\n{1} match(es)",
                           filtered.length)
    end
    Graphics.update
    Input.update
    searchwin.update
    cmdwin.update
    if filtered.length > 0   # Move the selection (the list ignores input itself)
      oldindex = cmdwin.index
      if Input.triggerex?(:DOWN) || Input.repeatex?(:DOWN)
        cmdwin.index = (cmdwin.index + 1) % filtered.length
      elsif Input.triggerex?(:UP) || Input.repeatex?(:UP)
        cmdwin.index = (cmdwin.index - 1 + filtered.length) % filtered.length
      elsif Input.triggerex?(:HOME)
        cmdwin.index = 0
      elsif Input.triggerex?(:END)
        cmdwin.index = filtered.length - 1
      end
      pbPlayCursorSE if cmdwin.index != oldindex
    end
    if Input.triggerex?(:RETURN)
      chosen = filtered[cmdwin.index]
      if chosen
        ret = chosen[2] || chosen[0]
        break
      end
    elsif Input.triggerex?(:ESCAPE)
      break
    end
  end
  Input.text_input = false
  searchwin.dispose
  cmdwin.dispose
  helpwin.dispose
  Input.update
  return ret
end

# sidmod: searchable picker over the BASE species (form 0, dex 1..max), built on
# pbChooseListSearchable. GameData::Species.each only walks the symbol-keyed
# entries (fusions are generated on demand by GameData::Species.get and are NOT
# in DATA), so this list is bounded by NB_POKEMON - no fusion explosion.
# "default" may be a species id symbol or a dex number. Returns the chosen
# GameData::Species entry (same as pbChooseSpeciesList), or nil if cancelled.
def pbChooseSpeciesListSearchable(default = nil, max = nil, what = _INTL("species"))
  max ||= (defined?(NB_POKEMON) ? NB_POKEMON : PBSpecies.maxValue)
  commands = []
  GameData::Species.each do |s|
    next if s.form != 0
    next if s.id_number < 1 || s.id_number > max
    commands.push([s.id_number, s.real_name, s.id])
  end
  return nil if commands.empty?
  ret = pbChooseListSearchable(commands, default, what)
  return nil if ret.nil?
  return GameData::Species.get(ret)
end

# sidmod: searchable picker over moves, built on pbChooseListSearchable.
# "move_ids", when given, restricts the list to exactly those moves (that is how
# the debug menu's "Teach legit move" stays inside pbGetLegalMoves); nil lists
# every move in the game. Returns a move id symbol, or nil if cancelled/empty.
def pbChooseMoveListSearchable(move_ids = nil, default = nil, what = _INTL("move"))
  commands = []
  if move_ids
    seen = {}
    move_ids.each do |m|
      move_data = GameData::Move.try_get(m)
      next if !move_data || seen[move_data.id]
      seen[move_data.id] = true
      commands.push([move_data.id_number, move_data.real_name, move_data.id])
    end
  else
    GameData::Move.each { |m| commands.push([m.id_number, m.real_name, m.id]) }
  end
  return nil if commands.empty?
  return pbChooseListSearchable(commands, default, what)
end

# Displays a list of all abilities, and returns the ID of the ability selected
# (or nil if the selection was canceled). "default", if specified, is the ID of
# the ability to initially select. Pressing Input::ACTION will toggle the list
# sorting between numerical and alphabetical.
def pbChooseAbilityList(default = nil)
  commands = []
  GameData::Ability.each { |a| commands.push([a.id_number, a.name, a.id]) }
  return pbChooseList(commands, default, nil, -1)
end

def pbChooseBallList(defaultMoveID = nil)
  cmdwin = pbListWindow([], 200)
  commands = []
  moveDefault = 0
  for key in $BallTypes.keys
    item = GameData::Item.try_get($BallTypes[key])
    commands.push([$BallTypes[key], item.name]) if item
  end
  commands.sort! { |a, b| a[1] <=> b[1] }
  if defaultMoveID
    for i in 0...commands.length
      moveDefault = i if commands[i][0] == defaultMoveID
    end
  end
  realcommands = []
  for i in commands
    realcommands.push(i[1])
  end
  ret = pbCommands2(cmdwin, realcommands, -1, moveDefault, true)
  cmdwin.dispose
  return (ret >= 0) ? commands[ret][0] : defaultMoveID
end



#===============================================================================
# General list methods
#===============================================================================
def pbCommands2(cmdwindow,commands,cmdIfCancel,defaultindex=-1,noresize=false)
  cmdwindow.commands = commands
  cmdwindow.index    = defaultindex if defaultindex>=0
  cmdwindow.x        = 0
  cmdwindow.y        = 0
  if noresize
    cmdwindow.height = Graphics.height
  else
    cmdwindow.width  = Graphics.width/2
  end
  cmdwindow.height   = Graphics.height if cmdwindow.height>Graphics.height
  cmdwindow.z        = 99999
  cmdwindow.visible  = true
  cmdwindow.active   = true
  command = 0
  loop do
    Graphics.update
    Input.update
    cmdwindow.update
    if Input.trigger?(Input::BACK)
      if cmdIfCancel>0
        command = cmdIfCancel-1
        break
      elsif cmdIfCancel<0
        command = cmdIfCancel
        break
      end
    elsif Input.trigger?(Input::USE)
      command = cmdwindow.index
      break
    end
  end
  ret = command
  cmdwindow.active = false
  return ret
end

def pbCommands3(cmdwindow,commands,cmdIfCancel,defaultindex=-1,noresize=false)
  cmdwindow.commands = commands
  cmdwindow.index    = defaultindex if defaultindex>=0
  cmdwindow.x        = 0
  cmdwindow.y        = 0
  if noresize
    cmdwindow.height = Graphics.height
  else
    cmdwindow.width  = Graphics.width/2
  end
  cmdwindow.height   = Graphics.height if cmdwindow.height>Graphics.height
  cmdwindow.z        = 99999
  cmdwindow.visible  = true
  cmdwindow.active   = true
  command = 0
  loop do
    Graphics.update
    Input.update
    cmdwindow.update
    if Input.trigger?(Input::SPECIAL)
      command = [5,cmdwindow.index]
      break
    elsif Input.press?(Input::ACTION)
      if Input.repeat?(Input::UP)
        command = [1,cmdwindow.index]
        break
      elsif Input.repeat?(Input::DOWN)
        command = [2,cmdwindow.index]
        break
      elsif Input.trigger?(Input::LEFT)
        command = [3,cmdwindow.index]
        break
      elsif Input.trigger?(Input::RIGHT)
        command = [4,cmdwindow.index]
        break
      end
    elsif Input.trigger?(Input::BACK)
      if cmdIfCancel>0
        command = [0,cmdIfCancel-1]
        break
      elsif cmdIfCancel<0
        command = [0,cmdIfCancel]
        break
      end
    elsif Input.trigger?(Input::USE)
      command = [0,cmdwindow.index]
      break
    end
  end
  ret = command
  cmdwindow.active = false
  return ret
end

def pbChooseList(commands, default = 0, cancelValue = -1, sortType = 1)
  cmdwin = pbListWindow([])
  itemID = default
  itemIndex = 0
  sortMode = (sortType >= 0) ? sortType : 0   # 0=ID, 1=alphabetical
  sorting = true
  loop do
    if sorting
      if sortMode == 0
        commands.sort! { |a, b| a[0] <=> b[0] }
      elsif sortMode == 1
        commands.sort! { |a, b| a[1] <=> b[1] }
      end
      if itemID.is_a?(Symbol)
        commands.each_with_index { |command, i| itemIndex = i if command[2] == itemID }
      elsif itemID && itemID > 0
        commands.each_with_index { |command, i| itemIndex = i if command[0] == itemID }
      end
      realcommands = []
      for command in commands
        if sortType <= 0
          realcommands.push(sprintf("%03d: %s", command[0], command[1]))
        else
          realcommands.push(command[1])
        end
      end
      sorting = false
    end
    cmd = pbCommandsSortable(cmdwin, realcommands, -1, itemIndex, (sortType < 0))
    if cmd[0] == 0   # Chose an option or cancelled
      itemID = (cmd[1] < 0) ? cancelValue : (commands[cmd[1]][2] || commands[cmd[1]][0])
      break
    elsif cmd[0] == 1   # Toggle sorting
      itemID = commands[cmd[1]][2] || commands[cmd[1]][0]
      sortMode = (sortMode + 1) % 2
      sorting = true
    end
  end
  cmdwin.dispose
  return itemID
end

def pbCommandsSortable(cmdwindow,commands,cmdIfCancel,defaultindex=-1,sortable=false)
  cmdwindow.commands = commands
  cmdwindow.index    = defaultindex if defaultindex >= 0
  cmdwindow.x        = 0
  cmdwindow.y        = 0
  cmdwindow.width    = Graphics.width / 2 if cmdwindow.width < Graphics.width / 2
  cmdwindow.height   = Graphics.height
  cmdwindow.z        = 99999
  cmdwindow.active   = true
  command = 0
  loop do
    Graphics.update
    Input.update
    cmdwindow.update
    if Input.trigger?(Input::ACTION) && sortable
      command = [1,cmdwindow.index]
      break
    elsif Input.trigger?(Input::BACK)
      command = [0,(cmdIfCancel>0) ? cmdIfCancel-1 : cmdIfCancel]
      break
    elsif Input.trigger?(Input::USE)
      command = [0,cmdwindow.index]
      break
    end
  end
  ret = command
  cmdwindow.active = false
  return ret
end
