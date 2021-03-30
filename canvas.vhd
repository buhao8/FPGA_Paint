library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library work;
use work.commonPak.all;

entity canvas is
  port (
    pixel_clk: in std_logic;
    xpos     : in std_logic_vector(11 downto 0);
    ypos     : in std_logic_vector(11 downto 0);
    left     : in std_logic;
    right    : in std_logic;

    hcount   : in std_logic_vector(11 downto 0);
    vcount   : in std_logic_vector(11 downto 0);
    
    enable_canvas_out : out std_logic;

    red_out  : out std_logic_vector(3 downto 0);
    green_out: out std_logic_vector(3 downto 0);
    blue_out : out std_logic_vector(3 downto 0);
    
    sw_rst   : in std_logic;
    
    color_in  : in std_logic_vector(11 downto 0);
    
    D_Red_C : out std_logic_vector (3 downto 0);
    D_Green_C : out std_logic_vector (3 downto 0);
    D_Blue_C : out std_logic_vector (3 downto 0);
    D_IN_C : out std_logic;
    D_VS_C : out std_logic
  );
end entity;

architecture Behavioral of canvas is
  constant SIZE    : INTEGER := 18;
  constant W       : INTEGER := 1280;
  constant H       : INTEGER := 720;
  constant START_X : INTEGER := W/2 - H/2;
  constant START_Y : INTEGER := 0;
  constant END_X   : INTEGER := W/2 + H/2;
  constant END_Y   : INTEGER := H;
  constant AMOUNT  : INTEGER := 40;
  
  type COLOR_MATRIX is array(0 to AMOUNT, 0 to AMOUNT) of std_logic_vector(11 downto 0);

  signal color_arr : COLOR_MATRIX := (others => (others => (others => '1')));

  signal fill_x, fill_y   : integer;
  signal click_x, click_y : integer;
  signal export_x, export_y : integer;
  
  signal text_on : STD_LOGIC := '0';
  
  signal D_IN_reg : std_logic := '0';
  signal D_VS_reg : std_logic := '0';
  signal export_count : integer := 0;
  signal export_inc : std_logic := '0';

begin
  process_click : process is
  begin
    wait until rising_edge(pixel_clk);
    if (sw_rst = '1') then
      color_arr <= (others => (others => (others => '1')));
    else
      click_x <= (to_integer(unsigned(xpos)) - START_X) / SIZE;
      click_y <= (to_integer(unsigned(ypos)) - START_Y) / SIZE;
      -- Must be within grid
      if (xpos >= START_X and xpos <= END_X) and (ypos >= START_Y and ypos <= END_Y) then
        if (left = '1') then
          color_arr(click_y, click_x) <= color_in;
        elsif (right = '1') then
          color_arr(click_y, click_x) <= (others => '1');
        end if;
      end if;
    end if;
  end process;

  draw_canvas : process is
  begin
    wait until rising_edge(pixel_clk);
    enable_canvas_out <= '1';  -- default show
  
    fill_x <= (to_integer(unsigned(hcount)) - START_X) / SIZE;
    fill_y <= (to_integer(unsigned(vcount)) - START_Y) / SIZE;
    if (text_on = '1') then
        red_out <= X"F";
        green_out <= X"F";
        blue_out <= X"F";
    elsif (hcount >= START_X and hcount <= END_X) and (vcount >= START_Y and vcount <= END_Y) then
      if ((to_integer(unsigned(hcount)) - START_X) mod SIZE) = 0 or ((to_integer(unsigned(vcount)) - START_Y) mod SIZE) = 0 then
        red_out   <= "0000";
        green_out <= "0000";
        blue_out  <= "0000";
      else
        red_out   <= color_arr(fill_y, fill_x)(11 downto 8);
        green_out <= color_arr(fill_y, fill_x)(7 downto 4);
        blue_out  <= color_arr(fill_y, fill_x)(3 downto 0);
      end if;
    else
      enable_canvas_out <= '0';
    end if;
  end process;

  export_canvas : process is
  begin
    wait until rising_edge(pixel_clk);
    export_count <= export_count + 1;
    export_inc <= '0';
    if export_count = 10000 then
      D_Red_C <= color_arr(export_y, export_x)(11 downto 8);
      D_Green_C <= color_arr(export_y, export_x)(7 downto 4);
      D_Blue_C <= color_arr(export_y, export_x)(3 downto 0);
      export_inc <= '1';
      D_IN_reg <= NOT D_IN_reg;
      export_count <= 0;
    end if;
    
    if export_x <= 0 and export_y <= 0 then
      D_VS_reg <= '1';
    else
      D_VS_reg <= '0';
    end if;
    
    if export_inc = '1' then
      if export_x = AMOUNT - 1 then
        if export_y = AMOUNT - 1 then
          export_y <= 0;
        else
          export_y <= export_y + 1;
        end if;
        export_x <= 0;
      else
        export_x <= export_x + 1;
      end if;
    end if;
    
  end process;

  D_IN_C <= D_IN_reg;
  D_VS_C <= D_VS_reg;


  textElement1: entity work.Pixel_On_Text
  generic map (
    textLength => 19
  )
  port map(
    clk => pixel_clk,
    displayText => "FPGA Paint Group #1",
    position => (5, 700),
    horzCoord => to_integer(signed(hcount)),
    vertCoord => to_integer(signed(vcount)),
    pixel => text_on
  );
  
  
end Behavioral;
