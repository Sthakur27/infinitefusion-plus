require_relative "engine"
SimEngine.boot
$DEBUG=false
def try(label); print "#{label}: "; puts(yield.inspect) rescue puts "FAIL #{$!.class}: #{$!.message[0,80]}"; end
try("Effectiveness.calculate(ELECTRIC vs GROUND)") { Effectiveness.calculate(:ELECTRIC, :GROUND) }
try("Effectiveness.calculate(WATER vs FIRE)") { Effectiveness.calculate(:WATER, :FIRE) }
try("Effectiveness.calculate(WATER vs WATER/GROUND)") { Effectiveness.calculate(:WATER, :WATER, :GROUND) }
try("NORMAL_EFFECTIVE const") { Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER rescue Effectiveness::NORMAL_EFFECTIVE }
try("ineffective? ELEC/GROUND") { Effectiveness.ineffective?(Effectiveness.calculate(:ELECTRIC, :GROUND)) }
