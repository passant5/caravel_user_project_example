if {\
  [catch {
    ##PT script
    # Adding SCL and IO link libraries based on the PDK and process corner specified
    if {[string match gf180* $::env(PDK)]} {
      source ./gf180_libs.tcl
    } elseif {[string match sky130* $::env(PDK)]} {
      source ./sky130_libs.tcl
    }

    # Reading design netlist
    set search_path "$::env(CARAVEL_ROOT)/verilog/gl $::env(MCW_ROOT)/verilog/gl $::env(UPRJ_ROOT)/verilog/gl"

    if {$::env(UPRJ_ROOT) == $::env(CARAVEL_ROOT)} {
      set verilogs [concat [glob $::env(CARAVEL_ROOT)/verilog/gl/*.v]]
    } elseif {$::env(MCW_ROOT) == $::env(CARAVEL_ROOT)} {
      set verilogs [concat [glob $::env(CARAVEL_ROOT)/verilog/gl/*.v] \
       [glob $::env(UPRJ_ROOT)/verilog/gl/*.v]]
    } elseif {$::env(UPRJ_ROOT) == $::env(CARAVEL_ROOT)} {
      set verilogs [concat [glob $::env(CARAVEL_ROOT)/verilog/gl/*.v] \
       [glob $::env(MCW_ROOT)/verilog/gl/*.v]]
    } else {
      set verilogs [concat [glob $::env(CARAVEL_ROOT)/verilog/gl/*.v] \
       [glob $::env(MCW_ROOT)/verilog/gl/*.v] \
       [glob $::env(UPRJ_ROOT)/verilog/gl/*.v]]
    }

    set verilog_exceptions [concat [glob $::env(CARAVEL_ROOT)/verilog/gl/*-signoff.v] \
      [glob $::env(CARAVEL_ROOT)/verilog/gl/__*.v]]

    foreach verilog_exception $verilog_exceptions {
        puts "verilog exception: $verilog_exception"
        set match_idx [lsearch $verilogs $verilog_exception]
        if {$match_idx} {
            puts "removing $verilog_exception from verilogs list"
            set verilogs [lreplace $verilogs $match_idx $match_idx]
        }
    }

    puts "list of verilog files:"
    foreach verilog $verilogs {
        puts $verilog
        read_verilog $verilog
    }

    current_design $::env(DESIGN)
    link
    
    proc constraints {io_mode} {
      ## MASTER CLOCKS
      set clk_period 25
      create_clock -name clk -period $clk_period [get_ports {clock}] 
      puts "\[INFO\]: Systemn clock period: $clk_period"

      create_clock -name hk_serial_clk -period 100 [get_pins {chip_core/housekeeping/serial_clock}]
      create_clock -name hk_serial_load -period 1000 [get_pins {chip_core/housekeeping/serial_load}]
      set_clock_uncertainty 0.1000 [get_clocks {clk hk_serial_clk hk_serial_load}]
      set_propagated_clock [get_clocks {clk hk_serial_clk hk_serial_load}]

      set min_clk_tran 1
      set max_clk_tran 1.5
      puts "\[INFO\]: Clock transition range: $min_clk_tran : $max_clk_tran"
   
      # Add clock transition
      set_input_transition -min $min_clk_tran [get_ports {clock}] 
      set_input_transition -max $max_clk_tran [get_ports {clock}] 

      # assert hkspi_disable
      set_case_analysis 1 [get_pins {chip_core/housekeeping/_7294_/Q}]

      set_clock_groups \
        -name clock_group \
        -logically_exclusive \
        -group [get_clocks {clk}]\
        -group [get_clocks {hk_serial_clk}]\
        -group [get_clocks {hk_serial_load}]

      # Add case analysis for clock pad DM[2]==1'b0 & DM[1]==1'b0 & DM[0]==1'b1 to be input
      set_case_analysis 0 [get_pins padframe/clock_pad/DM[2]]
      set_case_analysis 0 [get_pins padframe/clock_pad/DM[1]]
      set_case_analysis 1 [get_pins padframe/clock_pad/DM[0]]
      set_case_analysis 0 [get_pins padframe/clock_pad/INP_DIS]

      # Set system monitoring mux select to zero so that the clock/user_clk monitoring is disabled 
      set_case_analysis 0 [get_pins chip_core/housekeeping/_4166_/S]
      set_case_analysis 0 [get_pins chip_core/housekeeping/_4167_/S]

      set input_delay_value 4
      set output_delay_value 4
      puts "\[INFO\]: Setting input delay to: $input_delay_value"
      puts "\[INFO\]: Setting output delay to: $output_delay_value"

      set min_in_tran 1
      set max_in_tran 4
      puts "\[INFO\]: Input transition range: $min_in_tran : $max_in_tran"

      # 10 too high --> 4:7
      set min_cap 4
      set max_cap 7
      puts "\[INFO\]: Cap load range: $min_cap : $max_cap"
      if {$io_mode == "IN"} {
        # Add case analysis for pads DM[2]==1'b0 & DM[1]==1'b0 & DM[0]==1'b1 to be inputs
        set_case_analysis 0 [get_pins padframe/*mprj*/DM[2]]
        set_case_analysis 0 [get_pins padframe/*mprj*/DM[1]]
        set_case_analysis 1 [get_pins padframe/*mprj*/DM[0]]
        set_case_analysis 0 [get_pins padframe/*mprj*/INP_DIS]

        # Add input transition
        set_input_transition -min $min_in_tran [get_ports {mprj_io[*]}] 
        set_input_transition -max $max_in_tran [get_ports {mprj_io[*]}] 

        ## INPUT DELAYS
        set_input_delay $input_delay_value  -clock [get_clocks {clk}] -add_delay [get_ports {mprj_io[*]}]
      } elseif {$io_mode == "OUT"} {
        # Add case analysis for pads DM[2]==1'b1 & DM[1]==1'b1 & DM[0]==1'b0 to be outputs
        set_case_analysis 1 [get_pins padframe/*mprj*/DM[2]]
        set_case_analysis 1 [get_pins padframe/*mprj*/DM[1]]
        set_case_analysis 0 [get_pins padframe/*mprj*/DM[0]]
        set_case_analysis 1 [get_pins padframe/*mprj*/INP_DIS]

        # add loads for output ports (pads)
        set_load -min $min_cap [get_ports {mprj_io[*]}] 
        set_load -max $max_cap [get_ports {mprj_io[*]}]  

        ## OUTPUT DELAYS
        set_output_delay $output_delay_value  -clock [get_clocks {clk}] -add_delay [get_ports {mprj_io[*]}]
      }

      set derate 0.0375
      puts "\[INFO\]: Setting derate factor to: [expr $derate * 100] %"
      set_timing_derate -early [expr 1-$derate]
      set_timing_derate -late [expr 1+$derate]
    }

    # Reading parasitics based on the RC corner specified
    proc read_spefs {design rc_corner} {
      if {[string match gf180* $::env(PDK)]} {
        source ./gf180_spef_mapping.tcl
      } elseif {[string match sky130* $::env(PDK)]} {
        source ./sky130_spef_mapping.tcl
      }
      foreach key [array names spef_mapping] {
        read_parasitics -keep_capacitive_coupling -path $key $spef_mapping($key)
      }
      # add -complete_with wlm to let PT complete incomplete RC networks at the top-level
      read_parasitics -keep_capacitive_coupling $::env(ROOT)/signoff/${design}/openlane-signoff/spef/${design}.${rc_corner}.spef -pin_cap_included -complete_with wlm
      # read_parasitics -keep_capacitive_coupling $::env(ROOT)/signoff/${design}/openlane-signoff/spef/${design}.${rc_corner}.spef -pin_cap_included
      report_annotated_parasitics
    }

    proc report_results {io_mode} {
      if {$io_mode == "IN"} {
        for {set i 0} {$i < 365} {incr i} {
          report_timing -group clk -unique_pins -delay min -through [get_cells chip_core/mprj/i_FF[$i]] -path_type full -transition_time -capacitance -nosplit \
          -significant_digits 4 -include_hierarchical_pins >> $::env(CARAVEL_ROOT)/mprj-reports/in-min.rpt
        
          report_timing -group clk -unique_pins -delay max -through [get_cells chip_core/mprj/i_FF[$i]] -path_type full -transition_time -capacitance -nosplit \
          -significant_digits 4 -include_hierarchical_pins >> $::env(CARAVEL_ROOT)/mprj-reports/in-max.rpt
        }
        report_timing -unique_pins -delay min -through [get_pins chip_core/mprj/wb_rst_i] -path_type full -transition_time -capacitance -nosplit \
        -significant_digits 4 -include_hierarchical_pins >> $::env(CARAVEL_ROOT)/mprj-reports/in-min.rpt

        report_timing -unique_pins -delay max -through [get_pins chip_core/mprj/wb_rst_i] -path_type full -transition_time -capacitance -nosplit \
        -significant_digits 4 -include_hierarchical_pins >> $::env(CARAVEL_ROOT)/mprj-reports/in-max.rpt
      } elseif {$io_mode == "OUT"} {
        for {set i 0} {$i < 240} {incr i} {
          report_timing -group clk -unique_pins -delay min -through [get_cells chip_core/mprj/o_FF[$i]] -path_type full -transition_time -capacitance -nosplit \
          -significant_digits 4 -include_hierarchical_pins >> $::env(CARAVEL_ROOT)/mprj-reports/out-min.rpt
        
          report_timing -group clk -unique_pins -delay max -through [get_cells chip_core/mprj/o_FF[$i]] -path_type full -transition_time -capacitance -nosplit \
          -significant_digits 4 -include_hierarchical_pins >> $::env(CARAVEL_ROOT)/mprj-reports/out-max.rpt
        }
      }
    }

    set parasitics_log_file $::env(OUT_DIR)/logs/$::env(DESIGN)-$::env(RC_CORNER)-parasitics.log
    # set si_enable_analysis TRUE
    # set si_enable_analysis FALSE
    set sh_message_limit 1500
    read_spefs $::env(DESIGN) $::env(RC_CORNER)

    # Caravel+mprj specific constraints to extract I/O ports timing
    set io_mode IN
    constraints $io_mode
    update_timing
    report_results $io_mode 

    set io_mode OUT
    constraints $io_mode
    update_timing
    report_results $io_mode 

    set timing_report_unconstrained_paths TRUE

    # Caravel+mprj clock expanded timing report
    report_timing -group clk -unique_pins -delay min -through [get_cells {chip_core/mprj}] -path_type full_clock_expanded -transition_time -capacitance -nosplit \
    -significant_digits 4 -include_hierarchical_pins -start_end_type reg_to_reg >> $::env(CARAVEL_ROOT)/mprj-reports/clk-min.rpt

    report_timing -unique_pins -delay min -through [get_cells chip_core/mprj/user_clk2_FF] -path_type full_clock_expanded -transition_time -capacitance -nosplit \
    -significant_digits 4 -include_hierarchical_pins -start_end_type reg_to_reg >> $::env(CARAVEL_ROOT)/mprj-reports/clk-min.rpt

    report_timing -group clk -unique_pins -delay max -through [get_cells {chip_core/mprj}] -path_type full_clock_expanded -transition_time -capacitance -nosplit \
    -significant_digits 4 -include_hierarchical_pins -start_end_type reg_to_reg >> $::env(CARAVEL_ROOT)/mprj-reports/clk-max.rpt
    
    report_timing -unique_pins -delay max -through [get_cells chip_core/mprj/user_clk2_FF] -path_type full_clock_expanded -transition_time -capacitance -nosplit \
    -significant_digits 4 -include_hierarchical_pins -start_end_type reg_to_reg >> $::env(CARAVEL_ROOT)/mprj-reports/clk-max.rpt
    
    exit
  } err]
} {
  puts stderr $err
  exit 1
}