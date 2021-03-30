library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity color_pick is
    port(
        CLK_I       : in std_logic;
        SEG7_SEG    : out std_logic_vector(6 downto 0);
        SEG7_ANODE  : out std_logic_vector(7 downto 0);
        KB_COL      : out std_logic_vector(4 downto 1);
        KB_ROW      : in std_logic_vector(4 downto 1);
        LED_KB      : out std_logic;
        COLOR_OUT   : out std_logic_vector(11 downto 0)
    );   
end color_pick;

architecture Behavioral of color_pick is
    component keypad is
		port (
			samp_ck : in std_logic;
			col : out std_logic_vector(4 downto 1);
			row : in std_logic_vector(4 downto 1);
			value : out std_logic_vector(3 downto 0);
			hit : out std_logic
		);
    end component;
    component led_display is
        port (
			dig   : in std_logic_vector(1 downto 0);
			data  : in std_logic_vector(11 downto 0);
			anode : out std_logic_vector(7 downto 0);
			seg   : out std_logic_vector(6 downto 0)
		);
    end component;
    
    signal cnt                     : std_logic_vector(20 downto 0); -- counter to generate timing signals
	signal kp_clk, kp_hit, sm_clk  : std_logic;
	signal kp_value                : std_logic_vector(3 downto 0);
	signal nx_acc, acc             : std_logic_vector(11 downto 0);
	signal display                 : std_logic_vector(11 downto 0); -- value to be displayed
	signal led_mpx                 : std_logic_vector(1 downto 0); -- 7-seg multiplexing clock
	
	TYPE state IS (ENTER_ACC, ACC_RELEASE); -- state machine states
	signal pr_state, nx_state : state; -- present and next states
	
	
begin
    ck_proc : process (CLK_I)
	begin
		if rising_edge(CLK_I) then -- on rising edge of clock
			cnt <= cnt + 1; -- increment counter
		end if;
	end process;
	kp_clk <= cnt(15); -- keypad interrogation clock
	sm_clk <= cnt(20); -- state machine clock
	led_mpx <= cnt(18 downto 17); -- 7-seg multiplexing clock
	
	kp1 : keypad
	port map (
		samp_ck => kp_clk, col => KB_col, 
		row => KB_row, value => kp_value, hit => kp_hit
	);
	
	led1 : led_display
	port map(
		dig => led_mpx, data => display, 
		anode => SEG7_anode, seg => SEG7_seg
	);
	
	sm_ck_pr : process (sm_clk)
	begin
	   if rising_edge (sm_clk) then
	       pr_state <= nx_state;
	       acc <= nx_acc;
	       COLOR_OUT <= acc;
	   end if;
	end process;
	
	
	sm_comb_pr : process (kp_hit, kp_value, acc, pr_state)
	begin
	   LED_KB <= kp_hit;
	    nx_acc <= acc;
		display <= acc;
		case pr_state IS -- depending on present state...
			when ENTER_ACC => -- waiting for next digit in 1st operand entry
				if kp_hit = '1' then
					nx_acc <= acc(7 downto 0) & kp_value; -- get rid of top digit and push on new digit
					nx_state <= ACC_RELEASE;
				else
					nx_state <= ENTER_ACC;
				end if;
				
			when ACC_RELEASE => -- waiting for button to be released
				if kp_hit = '0' then
					nx_state <= ENTER_ACC;
					LED_KB <= '1';
				else 
				    nx_state <= ACC_RELEASE;
				end if;
				
		end case;
	end process;
	
end Behavioral;
