library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity led_display is
    port(   seg     : out std_logic_vector (6 downto 0);  -- segment code
            dig     : in std_logic_vector (1 downto 0);   -- ?
            anode   : out std_logic_vector (7 downto 0);  -- which position
            data    : in std_logic_vector (11 downto 0)  -- digits 2 - 0
        );
end led_display;

architecture Behavioral of led_display is
    signal data4 : std_logic_vector (3 downto 0); -- binary of digit
begin

	data4 <= data(3 downto 0) when dig = "00" else --digit 0
	         data(7 downto 4) when dig = "01" else --digit 1
	         data(11 downto 8) when dig = "10" else --digit 2
	         "0000";
	         --data(15 downto 12); --digit 3
	-- Turn on segments corresponding to 4-bit data word
	seg <= "0000001" when data4 = "0000" else --0
	       "1001111" when data4 = "0001" else --1
	       "0010010" when data4 = "0010" else --2
	       "0000110" when data4 = "0011" else --3
	       "1001100" when data4 = "0100" else --4
	       "0100100" when data4 = "0101" else --5
	       "0100000" when data4 = "0110" else --6
	       "0001111" when data4 = "0111" else --7
	       "0000000" when data4 = "1000" else --8
	       "0000100" when data4 = "1001" else --9
	       "0001000" when data4 = "1010" else --a
	       "1100000" when data4 = "1011" else --b
	       "0110001" when data4 = "1100" else --c
	       "1000010" when data4 = "1101" else --d
	       "0110000" when data4 = "1110" else --e
	       "0111000" when data4 = "1111" else --f
	       "1111111";
	-- Turn on anode of 7-segment display addressed by 2-bit digit selector dig
	-- 0 means on 1 means off
	anode <= "11111110" when dig = "00" else -- digit 0
	         "11111101" when dig = "01" else -- digit 1
	         "11111011" when dig = "10" else -- digit 2
	         --"11110111" when dig = "11" else -- digit 3
	         "11111111";

end Behavioral;
