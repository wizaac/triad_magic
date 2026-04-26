onerror resume
wave tags  sim
wave update off
wave zoom range 1003571951 1004544027
wave group {Top-level IOs} -backgroundcolor #004466
wave add -group {Top-level IOs} triad_magic_tb.clk -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.pin_rst_n -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.OLED_SCLK -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.OLED_MOSI -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.OLED_CS_N -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.OLED_DC -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.OLED_RST_N -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.ADC_SCLK -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.ADC_MOSI -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.ADC_MISO -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.ADC_CS_N -tag sim -radix hexadecimal
wave add -group {Top-level IOs} triad_magic_tb.led -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {ROM access} -backgroundcolor #006666
wave add -group {ROM access} triad_magic_tb.dut.ch0_rom_addr -tag sim -radix hexadecimal
wave add -group {ROM access} triad_magic_tb.dut.ch0_rom_en -tag sim -radix hexadecimal
wave add -group {ROM access} triad_magic_tb.dut.ch0_rom_data -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {Forklift State Machine} -backgroundcolor #226600
wave add -group {Forklift State Machine} triad_magic_tb.dut.ch0.mov_step -tag sim -radix mnemonic
wave add -group {Forklift State Machine} triad_magic_tb.dut.ch0.seq_state -tag sim -radix mnemonic
wave add -group {Forklift State Machine} triad_magic_tb.dut.ch0.pc -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {Chord Channel 0 Wishbone internal} -backgroundcolor #ffaa00
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_cyc -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_stb -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_we -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_addr -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_wdat -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_rdat -tag sim -radix hexadecimal -select
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.wb_ack -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.sel_disp -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.sel_adc -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.sel_chord -tag sim -radix hexadecimal
wave add -group {Chord Channel 0 Wishbone internal} triad_magic_tb.dut.ch0.sel_dec -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group ADC -backgroundcolor #664400
wave group {ADC:ADC Wishbone Top} -backgroundcolor #ffaa00
wave add -group {ADC:ADC Wishbone Top} triad_magic_tb.dut.ch0.adc.wb_cyc -tag sim -radix hexadecimal
wave add -group {ADC:ADC Wishbone Top} triad_magic_tb.dut.ch0.adc.wb_stb -tag sim -radix hexadecimal
wave add -group {ADC:ADC Wishbone Top} triad_magic_tb.dut.ch0.adc.wb_we -tag sim -radix hexadecimal
wave add -group {ADC:ADC Wishbone Top} triad_magic_tb.dut.ch0.adc.wb_addr -tag sim -radix hexadecimal
wave add -group {ADC:ADC Wishbone Top} triad_magic_tb.dut.ch0.adc.wb_rdat -tag sim -radix hexadecimal
wave add -group {ADC:ADC Wishbone Top} triad_magic_tb.dut.ch0.adc.wb_ack -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {ADC:ADC SPI Wishbone} -backgroundcolor #ee9900
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_cyc -tag sim -radix hexadecimal
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_stb -tag sim -radix hexadecimal
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_we -tag sim -radix hexadecimal
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_addr -tag sim -radix hexadecimal
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_wdat -tag sim -radix hexadecimal
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_rdat -tag sim -radix hexadecimal
wave add -group {ADC:ADC SPI Wishbone} triad_magic_tb.dut.ch0.adc.spi_wb_ack -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {ADC:ADC Registers} -backgroundcolor #660066
wave add -group {ADC:ADC Registers} triad_magic_tb.dut.ch0.adc.pot -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave insertion [expr [wave index insertpoint] + 1]
wave group Display -backgroundcolor #004466
wave group {Display:Disp Wishbone Top} -backgroundcolor #ffaa00
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_cyc -tag sim -radix hexadecimal
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_stb -tag sim -radix hexadecimal
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_we -tag sim -radix hexadecimal
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_addr -tag sim -radix hexadecimal
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_wdat -tag sim -radix hexadecimal -subitemconfig { {triad_magic_tb.dut.ch0.disp.wb_wdat[7]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[6]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[5]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[4]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[3]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[2]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[1]} {-radix hexadecimal} {triad_magic_tb.dut.ch0.disp.wb_wdat[0]} {-radix hexadecimal} }
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_rdat -tag sim -radix hexadecimal
wave add -group {Display:Disp Wishbone Top} triad_magic_tb.dut.ch0.disp.wb_ack -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {Display:Disp SPI Wishbone} -backgroundcolor #ee9900
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_cyc -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_stb -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_we -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_addr -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_wdat -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_rdat -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_wb_ack -tag sim -radix hexadecimal
wave add -group {Display:Disp SPI Wishbone} triad_magic_tb.dut.ch0.disp.spi_miso -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave insertion [expr [wave index insertpoint] + 1]
wave group {Chord Engine} -backgroundcolor #004466
wave group {Chord Engine:ENG Wishbone Top} -backgroundcolor #006666
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_cyc -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_stb -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_we -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_addr -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_wdat -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_rdat -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Wishbone Top} triad_magic_tb.dut.ch0.eng.wb_ack -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group {Chord Engine:ENG Registers} -backgroundcolor #226600
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_root_raw -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_quality_raw -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_inversion_raw -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_length_raw -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_root_note -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_bass_note -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_mid_note -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_high_note -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_duration -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.reg_chord_quality -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.invalid_read_err -tag sim -radix hexadecimal
wave add -group {Chord Engine:ENG Registers} triad_magic_tb.dut.ch0.eng.invalid_write_err -tag sim -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave insertion [expr [wave index insertpoint] + 1]
wave group {Display:Disp SPI Wishbone} -collapse
wave group {ADC:ADC Registers} -collapse
wave group {ADC:ADC SPI Wishbone} -collapse
wave group {ROM access} -collapse
wave group {Top-level IOs} -collapse
wave update on
wave top 21
