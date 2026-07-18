# Headless compatibility shim: fake the mkxp/RGSS runtime so the engine's .rb
# files can be eval'd without a graphics window. Permissive no-op stubs; we tighten
# as needed. Goal: let data/battle LOGIC load; visuals/audio/input are inert.

class RGSSStub
  def initialize(*); end
  def method_missing(*); self; end
  def respond_to_missing?(*); true; end
  def coerce(o); [o, 0]; end
  def to_i; 0; end
  def to_f; 0.0; end
  def to_s; ""; end
  def to_str; ""; end
  def to_ary; []; end
  def [](*); nil; end
  def []=(*); end
  def each; end
  def self.method_missing(*); new; end
  # Real (no-op) definitions for common RGSS methods so alias_method-based
  # compatibility patches (which need the method to already exist) don't blow up.
  %i[draw_text text_size blt stretch_blt fill_rect gradient_fill_rect clear clear_rect
     get_pixel set_pixel hue_change blur radial_blur dispose disposed? update flash
     width height rect resize font font= color color= tone tone= bitmap bitmap=
     viewport viewport= visible visible= x x= y y= z z= ox ox= oy oy=
     zoom_x zoom_x= zoom_y zoom_y= angle angle= opacity opacity= src_rect src_rect=
     mirror mirror= bush_depth bush_depth= blend_type blend_type= name name= size size=
     bold bold= italic italic= out_color out_color= shadow shadow=].each do |m|
    define_method(m) { |*| nil }
  end
end

# RGSS drawable/data classes
%w[Bitmap Sprite Viewport Plane Window Tilemap Font Color Tone Rect
   Win32API MiniFFI RPGVX Interpreter].each do |k|
  Object.const_set(k, Class.new(RGSSStub)) unless Object.const_defined?(k)
end
# Table can be marshalled in saves; keep a real-ish one but inert
Object.const_set(:Table, Class.new(RGSSStub)) unless Object.const_defined?(:Table)

# RGSS modules (method calls become no-ops; missing constants become 0)
module Graphics
  def self.update; end
  def self.transition(*); end
  def self.freeze; end
  def self.frame_reset; end
  def self.wait(*); end
  def self.frame_rate; 60; end
  def self.frame_rate=(_); end
  def self.frame_count; 0; end
  def self.frame_count=(_); end
  def self.width; 512; end
  def self.height; 384; end
  def self.method_missing(*); nil; end
end
module Input
  def self.update; end
  def self.press?(*); false; end
  def self.trigger?(*); false; end
  def self.repeat?(*); false; end
  def self.dir4; 0; end
  def self.dir8; 0; end
  def self.method_missing(*); false; end
  def self.const_missing(_); 0; end
end
module Audio
  def self.method_missing(*); nil; end
end
module RPG
  def self.const_missing(name); const_set(name, Class.new(RGSSStub)); end
  module Cache
    def self.method_missing(*); Bitmap.new; end
  end
end

# mkxp 'System' + misc globals the engine touches early
module System
  def self.method_missing(*); nil; end
  def self.data_directory; File.expand_path("."); end
  def self.platform; "Windows"; end
end unless defined?(System)

$RGSS_SCRIPTS = []
$DEBUG = false
$INTERNAL = false

# Let Marshal.load of a SAVE file work headless: RGSS Table/Color/Tone/Rect are
# userdef ('u') marshalled types. Capture their bytes raw and re-emit verbatim so
# loading a save (map data etc.) doesn't crash — we never inspect those objects.
[Table, Color, Tone, Rect, Bitmap].each do |k|
  k.define_singleton_method(:_load) { |s| o = allocate; o.instance_variable_set(:@__raw, s); o }
  k.send(:define_method, :_dump) { |_lvl| instance_variable_get(:@__raw) || "" }
end

# mkxp native file helpers (read/write marshalled data files) - the key ones
# GameData.load_all needs. IF is unencrypted, so plain Marshal works.
def load_data(filename)
  File.open(filename, "rb") { |f| Marshal.load(f) }
end
# SAFETY: the headless sim must NEVER write game files. save_data is neutered to a
# no-op so no engine boot/compile path can ever clobber a real .dat/.rxdata.
$SIM_BLOCKED_WRITES = []
def save_data(_data, filename)
  $SIM_BLOCKED_WRITES << filename
  nil
end

# Common global helpers referenced at load time in Essentials/mkxp
def pbSetResizeFactor(*); end
def rgss_main; yield if block_given?; end
def pbCriticalCode; yield if block_given?; end
def rgss_stop; end
def check_for_anim_folders; end unless defined?(check_for_anim_folders)
