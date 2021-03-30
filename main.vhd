----------------------------------------------------------------------------------
-- Company: CPE487 group #1
-- Engineer: Peter Ho
-- 
-- Create Date: 10/28/2019 07:29:45 PM
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

entity main is
  port (
    -- System
    CLKI    : in std_logic;
    
    -- VGA
    VGAHS_O    : out std_logic;
    VGAVS_O    : out std_logic;
    VGARED_O   : out std_logic_vector (3 downto 0);
    VGABLUE_O  : out std_logic_vector (3 downto 0);
    VGAGREEN_O : out std_logic_vector (3 downto 0);
    PS2CLK     : inout std_logic;
    PS2DATA    : inout std_logic;
    LEDSTATUS  : out std_logic;
    SWSTATUS   : in std_logic;
    
    DRed   : out std_logic_vector (3 downto 0);
    DGreen : out std_logic_vector (3 downto 0);
    DBlue  : out std_logic_vector (3 downto 0);
    DVS    : out std_logic;
    DIN    : out std_logic;
    

    -- Keyboard
    SEG7seg   : out std_logic_vector (6 downto 0);
    SEG7anode : out std_logic_vector (7 downto 0);
    KBcol     : out std_logic_vector (4 downto 1);
    KBrow     : in std_logic_vector (4 downto 1);
    LEDKB     : out std_logic;
    
    
    SWRST     : in std_logic
  );
end main;

architecture Behavioral of main is
  component vga_ctrl is
    port ( CLK_I    : in std_logic;
      VGA_HS_O   : out std_logic;
      VGA_VS_O   : out std_logic;
      VGA_RED_O  : out std_logic_vector (3 downto 0);
      VGA_BLUE_O   : out std_logic_vector (3 downto 0);
      VGA_GREEN_O  : out std_logic_vector (3 downto 0);
      PS2_CLK    : inout std_logic;
      PS2_DATA   : inout std_logic;
      LED_STATUS   : out std_logic;
      SW_STATUS  : in std_logic;
      SWRST_PASS : in std_logic;
      COLOR_PASS : in std_logic_vector(11 downto 0);
      
      D_Red : out std_logic_vector (3 downto 0);
      D_Green : out std_logic_vector (3 downto 0);
      D_Blue : out std_logic_vector (3 downto 0);
      D_VS : out std_logic;
      D_IN : out std_logic
    );
  end component;
  
  component color_pick is
    port(
      CLK_I     : in std_logic;
      SEG7_SEG  : out std_logic_vector (6 downto 0);
      SEG7_ANODE  : out std_logic_vector (7 downto 0);
      KB_COL    : out std_logic_vector (4 downto 1);
      KB_ROW    : in std_logic_vector (4 downto 1);
      LED_KB    : out std_logic;
      COLOR_OUT : out std_logic_vector(11 downto 0)
    );   
  end component;

  signal color : std_logic_vector (11 downto 0);
begin
  
  vga : vga_ctrl
  port map (
    CLK_I    => CLKI,
    VGA_HS_O   => VGAHS_O,
    VGA_VS_O   => VGAVS_O,
    VGA_RED_O  => VGARED_O,
    VGA_BLUE_O   => VGABLUE_O,
    VGA_GREEN_O  => VGAGREEN_O,
    PS2_CLK    => PS2CLK,
    PS2_DATA   => PS2DATA,
    LED_STATUS   => LEDSTATUS,
    SW_STATUS  => SWSTATUS,
    COLOR_PASS   => color,
    SWRST_PASS  => SWRST,
    
    D_Red => DRed,
    D_Green => DGreen,
    D_Blue => DBlue,
    D_VS => DVS,
    D_IN => DIN
    
  );
  
  display : color_pick
  port map(
    CLK_I     => CLKI,
    SEG7_SEG  => SEG7SEG,
    SEG7_ANODE  => SEG7ANODE,
    KB_COL    => KBCOL,
    KB_ROW    => KBROW,
    LED_KB    => LEDKB,
    COLOR_OUT => color
  );

end Behavioral;
