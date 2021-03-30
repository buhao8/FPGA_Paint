library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

--*** We use 12 bits for pixel coordinate b/c of resolution ***---

-- interface specification
entity vga_ctrl is
  port (
    CLK_I       : in std_logic;
    VGA_HS_O    : out std_logic;
    VGA_VS_O    : out std_logic;
    VGA_RED_O   : out std_logic_vector(3 downto 0);
    VGA_BLUE_O  : out std_logic_vector(3 downto 0);
    VGA_GREEN_O : out std_logic_vector(3 downto 0);
    PS2_CLK     : inout std_logic;
    PS2_DATA    : inout std_logic;
    LED_STATUS  : out std_logic;
    SW_STATUS   : in std_logic;
    SWRST_PASS  : in std_logic;
    COLOR_PASS  : in std_logic_vector(11 downto 0);
      
    D_Red : out std_logic_vector (3 downto 0);
    D_Green : out std_logic_vector (3 downto 0);
    D_Blue : out std_logic_vector (3 downto 0);
    D_VS : out std_logic;
    D_IN : out std_logic
  );
end vga_ctrl;

architecture Behavioral of vga_ctrl is
    
  component MouseCtl
  generic (
    SYSCLK_FREQUENCY_HZ : integer := 100000000;
     CHECK_PERIOD_MS     : integer := 500;
     TIMEOUT_PERIOD_MS   : integer := 100
  );
  port (
    clk       : in std_logic;
    rst       : in std_logic;
    value     : in std_logic_vector(11 downto 0);
    setx      : in std_logic;
    sety      : in std_logic;
    setmax_x  : in std_logic;
    setmax_y  : in std_logic;    
    ps2_clk   : inout std_logic;
    ps2_data  : inout std_logic;      
    xpos      : out std_logic_vector(11 downto 0);
    ypos      : out std_logic_vector(11 downto 0);
    zpos      : out std_logic_vector(3 downto 0);
    left      : out std_logic;
    middle    : out std_logic;
    right     : out std_logic;
    new_event : out std_logic
  );
  end component;
  
  component canvas
  port (
    pixel_clk           : in std_logic;
    xpos                : in std_logic_vector(11 downto 0);
    ypos                : in std_logic_vector(11 downto 0);
    hcount              : in std_logic_vector(11 downto 0);
    vcount              : in std_logic_vector(11 downto 0);
    left                : in std_logic;
    right               : in std_logic;
    enable_canvas_out   : out std_logic;
    red_out             : out std_logic_vector(3 downto 0);
    green_out           : out std_logic_vector(3 downto 0);
    blue_out            : out std_logic_vector(3 downto 0);
    sw_rst              : in std_logic;
    color_in            : in std_logic_vector(11 downto 0);      
    D_Red_C : out std_logic_vector (3 downto 0);
    D_Green_C : out std_logic_vector (3 downto 0);
    D_Blue_C : out std_logic_vector (3 downto 0);
    D_IN_C : out std_logic;
    D_VS_C : out std_logic
  );
  end component;
  
  component MouseDisplay
  port (
    pixel_clk                : in std_logic;
    xpos                     : in std_logic_vector(11 downto 0);
    ypos                     : in std_logic_vector(11 downto 0);
    hcount                   : in std_logic_vector(11 downto 0);
    vcount                   : in std_logic_vector(11 downto 0);          
    enable_mouse_display_out : out std_logic;
    red_out                  : out std_logic_vector(3 downto 0);
    green_out                : out std_logic_vector(3 downto 0);
    blue_out                 : out std_logic_vector(3 downto 0)
   );
  end component;

  component clk_wiz_0
  port (
    clk_in1  : in  std_logic;
    clk_out1 : out std_logic
  );
  end component;

  --***1280x720@60Hz***--
  constant FRAME_WIDTH  : natural := 1280;
  constant FRAME_HEIGHT : natural := 720;
  
  constant H_FP  : natural := 110;    --H front porch
  constant H_PW  : natural := 40;     --H sync pulse
  constant H_MAX : natural := 1650;   --H total period
  
  constant V_FP  : natural := 5;      --V front porch
  constant V_PW  : natural := 5;      --V sync pulse
  constant V_MAX : natural := 750;    --V total period
  
  constant H_POL : std_logic := '1';  --H polarity
  constant V_POL : std_logic := '1';  --V polarity
  
  -----------------------------------------------------------
  -- VGA Controller specific signals: Counters, Sync, R, G, B
  -----------------------------------------------------------
  -- Pixel clock, in this case 74.250 MHz
  signal pxl_clk : std_logic;
  -- The active signal is used to signal the active region of the screen (when not blank)
  signal active  : std_logic;
  
  -- Horizontal and Vertical counters
  signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
  signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
  
  -- Pipe Horizontal and Vertical Counters
  signal h_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');
  signal v_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');
  
  -- Horizontal and Vertical Sync
  signal h_sync_reg : std_logic := not(H_POL);
  signal v_sync_reg : std_logic := not(V_POL);
  -- Pipe Horizontal and Vertical Sync
  signal h_sync_reg_dly : std_logic := not(H_POL);
  signal v_sync_reg_dly : std_logic :=  not(V_POL);
  
  -- VGA R, G and B signals coming from the main multiplexers
  signal vga_red_cmb   : std_logic_vector(3 downto 0);
  signal vga_green_cmb : std_logic_vector(3 downto 0);
  signal vga_blue_cmb  : std_logic_vector(3 downto 0);
  --The main VGA R, G and B signals, validated by active
  signal vga_red    : std_logic_vector(3 downto 0);
  signal vga_green  : std_logic_vector(3 downto 0);
  signal vga_blue   : std_logic_vector(3 downto 0);
  -- Register VGA R, G and B signals
  signal vga_red_reg   : std_logic_vector(3 downto 0) := (others =>'0');
  signal vga_green_reg : std_logic_vector(3 downto 0) := (others =>'0');
  signal vga_blue_reg  : std_logic_vector(3 downto 0) := (others =>'0');
  
  -------------------------------------------------------------------------
  -- Canvas signals
  -------------------------------------------------------------------------
  -- Display signals
  signal menu_red    : std_logic_vector (3 downto 0) := (others => '0');
  signal menu_blue   : std_logic_vector (3 downto 0) := (others => '0');
  signal menu_green  : std_logic_vector (3 downto 0) := (others => '0');

  -- Enable
  signal enable_menu:  std_logic;

  -- Registered Display signals (pipe)
  signal menu_red_dly   : std_logic_vector (3 downto 0) := (others => '0');
  signal menu_blue_dly  : std_logic_vector (3 downto 0) := (others => '0');
  signal menu_green_dly : std_logic_vector (3 downto 0) := (others => '0');

  -- Registered Enable (pipe)
  signal enable_menu_dly  :  std_logic;

  -------------------------------------------------------------------------
  -- Canvas signals
  -------------------------------------------------------------------------
  -- Display signals
  signal canvas_red    : std_logic_vector (3 downto 0) := (others => '0');
  signal canvas_blue   : std_logic_vector (3 downto 0) := (others => '0');
  signal canvas_green  : std_logic_vector (3 downto 0) := (others => '0');

  -- Enable
  signal enable_canvas:  std_logic;

  -- Registered Display signals (pipe)
  signal canvas_red_dly   : std_logic_vector (3 downto 0) := (others => '0');
  signal canvas_blue_dly  : std_logic_vector (3 downto 0) := (others => '0');
  signal canvas_green_dly : std_logic_vector (3 downto 0) := (others => '0');

  -- Registered Enable (pipe)
  signal enable_canvas_dly  :  std_logic;

  -------------------------------------------------------------------------
  --Mouse pointer signals
  -------------------------------------------------------------------------
  
  -- Data signals
  signal MOUSE_X_POS     : std_logic_vector (11 downto 0);
  signal MOUSE_Y_POS     : std_logic_vector (11 downto 0);
  signal MOUSE_X_POS_REG : std_logic_vector (11 downto 0);
  signal MOUSE_Y_POS_REG : std_logic_vector (11 downto 0);
  signal MOUSE_LEFT_REG  : std_logic;
  signal MOUSE_RIGHT_REG : std_logic;
  
  -- Display signals
  signal mouse_cursor_red    : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_blue   : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_green  : std_logic_vector (3 downto 0) := (others => '0');

  -- Enable
  signal enable_mouse_display:  std_logic;

  -- Registered Display signals (pipe)
  signal mouse_cursor_red_dly   : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_blue_dly  : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_green_dly : std_logic_vector (3 downto 0) := (others => '0');

  -- Registered Enable (pipe)
  signal enable_mouse_display_dly  :  std_logic;
  
  

begin    
  -- Pixel clock
  clk_wiz_0_inst : clk_wiz_0
  port map (
    clk_in1 => CLK_I,
    clk_out1 => pxl_clk
  );

  -- Mouse Controller
  Inst_MouseCtl: MouseCtl
  generic map (
    --SYSCLK_FREQUENCY_HZ => 108000000,
    SYSCLK_FREQUENCY_HZ => 74250000,
    CHECK_PERIOD_MS     => 500,
    TIMEOUT_PERIOD_MS   => 100
  )
  port map (
    clk       => pxl_clk,
    rst       => '0',
    xpos      => MOUSE_X_POS,
    ypos      => MOUSE_Y_POS,
    zpos      => open,
    left      => MOUSE_LEFT_REG,
    middle    => open,
    right     => MOUSE_RIGHT_REG,
    new_event => open,
    value     => x"000",
    setx      => '0',
    sety      => '0',
    setmax_x  => '0',
    setmax_y  => '0',
    ps2_clk   => PS2_CLK,
    ps2_data  => PS2_DATA
  );
  
  --------------------------------------------------------------
  -- Generate Horizontal, Vertical counters and the Sync signals
  --------------------------------------------------------------
  -- Horizontal counter
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (h_cntr_reg = (H_MAX - 1)) then
        h_cntr_reg <= (others =>'0');
      else
        h_cntr_reg <= h_cntr_reg + 1;
      end if;
    end if;
  end process;
  -- Vertical counter
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if ((h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1))) then
        v_cntr_reg <= (others =>'0');
      elsif (h_cntr_reg = (H_MAX - 1)) then
        v_cntr_reg <= v_cntr_reg + 1;
      end if;
    end if;
  end process;
  -- Horizontal sync
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) and (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) then
        h_sync_reg <= H_POL;
      else
        h_sync_reg <= not(H_POL);
      end if;
    end if;
  end process;
  -- Vertical sync
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) and (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) then
        v_sync_reg <= V_POL;
      else
        v_sync_reg <= not(V_POL);
      end if;
    end if;
  end process;
  
  --------------------
  -- The active signal
  --------------------
  active <= '1' when h_cntr_reg_dly < FRAME_WIDTH and v_cntr_reg_dly < FRAME_HEIGHT
    else '0';
  
  ------------------
  -- Register Inputs
  ------------------
  register_inputs: process (pxl_clk)
  begin
      if (rising_edge(pxl_clk)) then  
        if v_sync_reg = V_POL then
          MOUSE_X_POS_REG <= MOUSE_X_POS;
          MOUSE_Y_POS_REG <= MOUSE_Y_POS;
        end if;   
      end if;
  end process register_inputs;

  ----------------------------------
  -- Canvas display instance
  ----------------------------------
  canvas_display: canvas
  port map (
    pixel_clk          => pxl_clk,
    xpos               => MOUSE_X_POS_REG, 
    ypos               => MOUSE_Y_POS_REG,
    left               => MOUSE_LEFT_REG,
    right              => MOUSE_RIGHT_REG,
    hcount             => h_cntr_reg,
    vcount             => v_cntr_reg,
    enable_canvas_out  => enable_canvas,
    red_out            => canvas_red,
    green_out          => canvas_green,
    blue_out           => canvas_blue,
    sw_rst             => SWRST_PASS,
    color_in           => COLOR_PASS,
    
    D_Red_C => D_Red,
    D_Green_C => D_Green,
    D_Blue_C => D_Blue,
    D_IN_C => D_IN,
    D_VS_C => D_VS
  );

  ----------------------------------
  -- Mouse Cursor display instance
  ----------------------------------
  Inst_MouseDisplay: MouseDisplay
  port map (
    pixel_clk   => pxl_clk,
    xpos        => MOUSE_X_POS_REG, 
    ypos        => MOUSE_Y_POS_REG,
    hcount      => h_cntr_reg,
    vcount      => v_cntr_reg,
    enable_mouse_display_out  => enable_mouse_display,
    red_out     => mouse_cursor_red,
    green_out   => mouse_cursor_green,
    blue_out    => mouse_cursor_blue
  );
  
  ---------------------------------------------------------------------------------------------------
  -- Register Outputs coming from the displaying components and the horizontal and vertical counters
  ---------------------------------------------------------------------------------------------------
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
  
      --bg_red_dly            <= bg_red;
      --bg_green_dly          <= bg_green;
      --bg_blue_dly           <= bg_blue;

      canvas_red_dly    <= canvas_red;
      canvas_blue_dly   <= canvas_blue;
      canvas_green_dly  <= canvas_green;
      
      enable_canvas_dly   <= enable_canvas;


      mouse_cursor_red_dly    <= mouse_cursor_red;
      mouse_cursor_blue_dly   <= mouse_cursor_blue;
      mouse_cursor_green_dly  <= mouse_cursor_green;
      
      enable_mouse_display_dly   <= enable_mouse_display;
      
      h_cntr_reg_dly <= h_cntr_reg;
      v_cntr_reg_dly <= v_cntr_reg;

    end if;
  end process;

  ----------------------------------
  -- VGA Output Muxing
  ----------------------------------
  vga_red   <= mouse_cursor_red_dly when enable_mouse_display_dly = '1'
        else canvas_red_dly when enable_canvas_dly = '1'
        else COLOR_PASS(11 downto 8);
  vga_green <= mouse_cursor_green_dly when enable_mouse_display_dly = '1'
        else canvas_green_dly when enable_canvas_dly = '1'
        else COLOR_PASS(7 downto 4);
  vga_blue  <= mouse_cursor_blue_dly when enable_mouse_display_dly = '1'
        else canvas_blue_dly when enable_canvas_dly = '1'
        else COLOR_PASS(3 downto 0);
         
  ------------------------------------------------------------
  -- Turn Off VGA RBG Signals if outside of the active screen
  -- Make a 4-bit AND logic with the R, G and B signals
  ------------------------------------------------------------
  vga_red_cmb <= (active & active & active & active) and vga_red;
  vga_green_cmb <= (active & active & active & active) and vga_green;
  vga_blue_cmb <= (active & active & active & active) and vga_blue;
  
  
  -- Register Outputs
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      v_sync_reg_dly <= v_sync_reg;
      h_sync_reg_dly <= h_sync_reg;
      vga_red_reg    <= vga_red_cmb;
      vga_green_reg  <= vga_green_cmb;
      vga_blue_reg   <= vga_blue_cmb;
    end if;
  end process;
  
  -- Assign outputs
  VGA_HS_O     <= h_sync_reg_dly;
  VGA_VS_O     <= v_sync_reg_dly;
  VGA_RED_O    <= vga_red_reg;
  VGA_GREEN_O  <= vga_green_reg;
  VGA_BLUE_O   <= vga_blue_reg;

  
  -- Mouse status
  LED_STATUS   <= NOT(PS2_DATA) AND SW_STATUS;

end Behavioral;
