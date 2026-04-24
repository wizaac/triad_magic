module adc_to_screen_test_tb;

	adc_to_screen_test adc();

	initial begin
		#50ms;
		$finish;
	end
endmodule
