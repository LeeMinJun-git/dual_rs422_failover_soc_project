# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "COUNTER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "HIGH_THRESHOLD_DEFAULT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LOW_THRESHOLD_DEFAULT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_DELTA_DEFAULT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "STALE_LIMIT_DEFAULT" -parent ${Page_0}


}

proc update_PARAM_VALUE.COUNTER_WIDTH { PARAM_VALUE.COUNTER_WIDTH } {
	# Procedure called to update COUNTER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.COUNTER_WIDTH { PARAM_VALUE.COUNTER_WIDTH } {
	# Procedure called to validate COUNTER_WIDTH
	return true
}

proc update_PARAM_VALUE.HIGH_THRESHOLD_DEFAULT { PARAM_VALUE.HIGH_THRESHOLD_DEFAULT } {
	# Procedure called to update HIGH_THRESHOLD_DEFAULT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HIGH_THRESHOLD_DEFAULT { PARAM_VALUE.HIGH_THRESHOLD_DEFAULT } {
	# Procedure called to validate HIGH_THRESHOLD_DEFAULT
	return true
}

proc update_PARAM_VALUE.LOW_THRESHOLD_DEFAULT { PARAM_VALUE.LOW_THRESHOLD_DEFAULT } {
	# Procedure called to update LOW_THRESHOLD_DEFAULT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LOW_THRESHOLD_DEFAULT { PARAM_VALUE.LOW_THRESHOLD_DEFAULT } {
	# Procedure called to validate LOW_THRESHOLD_DEFAULT
	return true
}

proc update_PARAM_VALUE.MAX_DELTA_DEFAULT { PARAM_VALUE.MAX_DELTA_DEFAULT } {
	# Procedure called to update MAX_DELTA_DEFAULT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_DELTA_DEFAULT { PARAM_VALUE.MAX_DELTA_DEFAULT } {
	# Procedure called to validate MAX_DELTA_DEFAULT
	return true
}

proc update_PARAM_VALUE.STALE_LIMIT_DEFAULT { PARAM_VALUE.STALE_LIMIT_DEFAULT } {
	# Procedure called to update STALE_LIMIT_DEFAULT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.STALE_LIMIT_DEFAULT { PARAM_VALUE.STALE_LIMIT_DEFAULT } {
	# Procedure called to validate STALE_LIMIT_DEFAULT
	return true
}


proc update_MODELPARAM_VALUE.LOW_THRESHOLD_DEFAULT { MODELPARAM_VALUE.LOW_THRESHOLD_DEFAULT PARAM_VALUE.LOW_THRESHOLD_DEFAULT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LOW_THRESHOLD_DEFAULT}] ${MODELPARAM_VALUE.LOW_THRESHOLD_DEFAULT}
}

proc update_MODELPARAM_VALUE.HIGH_THRESHOLD_DEFAULT { MODELPARAM_VALUE.HIGH_THRESHOLD_DEFAULT PARAM_VALUE.HIGH_THRESHOLD_DEFAULT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HIGH_THRESHOLD_DEFAULT}] ${MODELPARAM_VALUE.HIGH_THRESHOLD_DEFAULT}
}

proc update_MODELPARAM_VALUE.MAX_DELTA_DEFAULT { MODELPARAM_VALUE.MAX_DELTA_DEFAULT PARAM_VALUE.MAX_DELTA_DEFAULT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_DELTA_DEFAULT}] ${MODELPARAM_VALUE.MAX_DELTA_DEFAULT}
}

proc update_MODELPARAM_VALUE.STALE_LIMIT_DEFAULT { MODELPARAM_VALUE.STALE_LIMIT_DEFAULT PARAM_VALUE.STALE_LIMIT_DEFAULT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.STALE_LIMIT_DEFAULT}] ${MODELPARAM_VALUE.STALE_LIMIT_DEFAULT}
}

proc update_MODELPARAM_VALUE.COUNTER_WIDTH { MODELPARAM_VALUE.COUNTER_WIDTH PARAM_VALUE.COUNTER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.COUNTER_WIDTH}] ${MODELPARAM_VALUE.COUNTER_WIDTH}
}

