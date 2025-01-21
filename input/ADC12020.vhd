LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.numeric_std.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity ADC12020 is
  Port (
    i_ad_clk              : in  std_logic;    -- 20
    i_sys_clk             : in  std_logic;    -- 80
    i_rst_b               : in  std_logic;

    i_adc_data            : in  std_logic_vector(11 downto 0);

    i_rx_start            : in  std_logic;
    i_ave_line            : in  std_logic_vector(5 downto 0);

    -- i_buffer_add_reset    : in std_logic; -- org
    i_burst_type          : in std_logic_vector(1 downto 0);
    i_buffer_add_reset    : in std_logic_vector(1 downto 0);

    i_local_burst_index   : in std_logic; -- IMU:1 or US:0
    i_local_burst_rd      : in std_logic;
    i_local_burst_rd_end  : in std_logic;

    o_ave_tx_trg          : out std_logic;
    o_rx_done             : out std_logic;

    i_imu_trig           : in std_logic;

    o_burst_us_req        : out std_logic;
    o_burst_imu_req       : out std_logic;

    o_burst_data_en       : out std_logic;
    o_burst_data          : out std_logic_vector(15 downto 0)
  );
end ADC12020;

architecture Behavioral of ADC12020 is

  attribute IOB : string;

  type state_type is (st_idle,
                      st_line_ave0,
                      st_line_ave1,
                      st_line_ave2,
                      st_line_ave3,
                      st_line_ave4,
                      st_wr0,
                      st_wr1,
                      st_done);
  signal state                : state_type := st_idle;

  signal s_ad_din             : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
  attribute IOB of s_ad_din   : signal is "TRUE";

  signal s_ave_tx             : std_logic := '0';
  signal s_ave_tx_d           : std_logic := '0';

  signal s_ave_cnt            : std_logic_vector(5 downto 0) := (others => '0');
  signal s_state_cnt          : std_logic_vector(7 downto 0) := (others => '0');

  signal s_fifo_wr0           : std_logic := '0';
  signal s_fifo_rd0           : std_logic := '0';
  signal s_fifo_din0          : std_logic_vector(16 downto 0) := (others => '0');
  signal s_fifo_dout0         : std_logic_vector(16 downto 0);

  signal s_fifo_wr1           : std_logic := '0';
  signal s_fifo_rd1           : std_logic := '0';
  signal s_fifo_din1          : std_logic_vector(16 downto 0) := (others => '0');
  signal s_fifo_dout1         : std_logic_vector(16 downto 0);

  signal s_fifo_cnt           : std_logic_vector(15 downto 0) := (others => '0');

  signal s_ad_wr              : STD_LOGIC_VECTOR(0 downto 0) := "0";
  signal s_ad_arddr           : STD_LOGIC_VECTOR(13 downto 0) := (others => '0');
  signal s_ad_din_ave         : std_logic_vector(16 downto 0) := (others => '0');
  signal s_ad_din_ave_d       : std_logic_vector(11 downto 0);

  signal s_rx_done            : std_logic := '0';

  signal s_buffer_add_reset   : std_logic := '0';
  signal s_buffer_add         : STD_LOGIC_VECTOR(13 downto 0);
  signal s_buffer_dout        : STD_LOGIC_VECTOR(15 downto 0);

  signal s_local_burst_rd     : std_logic;
  signal s_local_burst_rd_end : std_logic;
  signal s_burst_data_en      : std_logic;
  signal s_burst_data         : std_logic_vector(15 downto 0);

  signal s_burst_us_req       : std_logic := '0';
  signal s_burst_data_us      : std_logic_vector(15 downto 0) := (others => '0');

  signal s_burst_imu_req      : std_logic := '0';
  signal s_burst_data_imu     : std_logic_vector(15 downto 0) := x"A003";

begin

  process(i_ad_clk) is
  begin
    if rising_edge(i_ad_clk) then
      s_ad_din <= i_adc_data;
    end if;
  end process;

--------------------------------------------------------------------------------
-- ADC buffer
--------------------------------------------------------------------------------
  process(i_ad_clk) is
  begin
    if rising_edge(i_ad_clk) then
      s_ave_tx_d <= s_ave_tx;
      case state is
        when st_idle =>
          s_ave_tx <= '0';
          if (i_rx_start = '1') then
            if (i_ave_line /= 0) then
              if (i_ave_line - '1' /= s_ave_cnt) then
                state <= st_line_ave0;  -- 1, n+1 라인
              else
                state <= st_line_ave3;  -- 마지막 라인
              end if;
            else
              state <= st_wr0;           -- Average X
            end if;
          end if;

          when st_line_ave0 =>
            s_state_cnt <= s_state_cnt + '1';
            if (s_ave_cnt = 0) then
              if (s_state_cnt = 1) then
                state <= st_line_ave1;  -- first line
                s_fifo_rd0 <= '0';
                s_fifo_rd1 <= '0';
                s_state_cnt <= (others => '0');
              end if;
            else
              if (s_state_cnt = 1) then
                s_state_cnt <= (others => '0');
                state <= st_line_ave2;  -- n line
              end if;
              if (s_ave_cnt(0) = '1') then
                s_fifo_rd0 <= '1';
                s_fifo_rd1 <= '0';
              else
                s_fifo_rd0 <= '0';
                s_fifo_rd1 <= '1';
              end if;
            end if;

          when st_line_ave1 => -- first line
            s_fifo_cnt <= s_fifo_cnt + '1';
            -- if (s_fifo_cnt = 16384) then
            if (s_fifo_cnt = 5120) then
              s_fifo_cnt <= (others => '0');
              s_fifo_wr0 <= '0';
              state <= st_done;
              s_rx_done <= '1';
            else
              s_fifo_wr0 <= '1';
              s_fifo_din0 <= "00000" & s_ad_din;
            end if;

          when st_line_ave2 => -- n line
            s_fifo_cnt <= s_fifo_cnt + '1';
            s_fifo_din0 <= s_fifo_dout1 + s_ad_din;
            s_fifo_din1 <= s_fifo_dout0 + s_ad_din;

            -- if (s_fifo_cnt = 16382) then
            if (s_fifo_cnt = 5198) then
              s_fifo_rd0 <= '0';
              s_fifo_rd1 <= '0';
            -- elsif (s_fifo_cnt = 16384) then
            elsif (s_fifo_cnt = 5120) then
              s_fifo_cnt <= (others => '0');
              s_fifo_wr0 <= '0';
              s_fifo_wr1 <= '0';
              s_fifo_rd0 <= '0';
              s_fifo_rd1 <= '0';
              state <= st_done;
              s_rx_done <= '1';
            elsif (s_ave_cnt(0) = '1') then
              s_fifo_wr0 <= '0';
              s_fifo_wr1 <= '1';
            elsif (s_ave_cnt(0) = '0') then
              s_fifo_wr0 <= '1';
              s_fifo_wr1 <= '0';
            end if;

          when st_line_ave3 =>
            s_fifo_rd0  <= '1';
            s_state_cnt <= s_state_cnt + '1';
            if (s_state_cnt = 1) then
              state       <= st_line_ave4;
              s_state_cnt <= (others => '0');
            end if;

          when st_line_ave4 =>
            s_ad_wr <= "1";
            s_ad_din_ave <= s_fifo_dout0 + s_ad_din;
            -- if (s_ad_arddr = 16381) then
            if (s_ad_arddr = 5117) then
              s_fifo_rd0 <= '0';
              s_ad_arddr <= s_ad_arddr + '1';
            -- elsif (s_ad_arddr = 16383) then
            elsif (s_ad_arddr = 5119) then
              s_ad_wr <= "0";
              s_ad_arddr <= (others => '0');
              state <= st_done;
              s_rx_done <= '1';
            elsif (s_ad_wr = "1") then
              s_ad_arddr <= s_ad_arddr + '1';
            end if;

          when st_wr0 =>
            state <= st_wr1;

          when st_wr1 =>
            s_ad_wr <= "1";
            -- if (s_ad_arddr = 16383) then
            if (s_ad_arddr = 5119) then
              s_ad_arddr <= (others => '0');
              s_ad_wr <= "0";
              state <= st_done;
              s_rx_done <= '1';
            elsif (s_ad_wr = "1") then
              s_ad_arddr <= s_ad_arddr + '1';
            end if;

          when st_done =>
            s_fifo_wr0 <= '0';
            s_fifo_wr1 <= '0';
            s_ad_arddr <= (others => '0');
            s_state_cnt <= s_state_cnt + '1';
            --  if (s_state_cnt = 90) then
            if (s_state_cnt = 255) then
              if (i_ave_line /= 0 and i_ave_line - '1' /= s_ave_cnt) then
                s_ave_cnt   <= s_ave_cnt + '1';
                s_ave_tx    <= '1';
                state       <= st_idle;
                s_rx_done   <= '0';
                s_state_cnt <= (others => '0');
              else
                s_ave_cnt   <= (others => '0');
                s_ave_tx    <= '0';
                state       <= st_idle;
                s_rx_done   <= '0';
                s_state_cnt <= (others => '0');
              end if;
            end if;
          when others => null;
      end case;
    end if;
  end process;

  process(i_sys_clk) is
  begin
    if rising_edge(i_sys_clk) then
      if (i_buffer_add_reset(0) = '1') then
        -- s_burst_us_req <= '0';
      elsif (s_state_cnt > 20) then
        if (i_ave_line /= 0) then
          if (i_ave_line - '1' = s_ave_cnt) then
            s_burst_us_req <= '1';
          end if;
        else
          s_burst_us_req <= '1';
        end if;
      end if;
    end if;
  end process;

  process(i_ad_clk) is
  begin
    if rising_edge(i_ad_clk) then
      if (i_buffer_add_reset(1) = '1') then
        -- s_burst_imu_req <= '0';
      elsif (i_imu_trig = '1') then
        s_burst_imu_req <= '1';
      end if;
    end if;
  end process;

  o_rx_done     <= s_rx_done;
  o_ave_tx_trg  <= '1' when (s_ave_tx_d = '1' and s_ave_tx = '0') else '0';

  U_fifo_generator_0 : entity work.fifo_generator_0
  PORT map (
    clk         => i_ad_clk      ,
    rst         => not i_rst_b      ,
    din         => s_fifo_din0      ,
    wr_en       => s_fifo_wr0  ,
    rd_en       => s_fifo_rd0  ,
    dout        => s_fifo_dout0      ,
    full        => open      ,
    empty       => open
  );

  U_fifo_generator_1 : entity work.fifo_generator_0
  PORT map (
    clk         => i_ad_clk      ,
    rst         => not i_rst_b      ,
    din         => s_fifo_din1      ,
    wr_en       => s_fifo_wr1      ,
    rd_en       => s_fifo_rd1      ,
    dout        => s_fifo_dout1      ,
    full        => open      ,
    empty       => open
  );

  s_ad_din_ave_d <= s_ad_din when (i_ave_line = 0) else
                    s_ad_din_ave(16 downto 5) when (i_ave_line = 32) else
                    s_ad_din_ave(15 downto 4) when (i_ave_line = 16) else
                    s_ad_din_ave(14 downto 3) when (i_ave_line = 8) else
                    s_ad_din_ave(13 downto 2) when (i_ave_line = 4) else
                    s_ad_din_ave(12 downto 1) when (i_ave_line = 2);

  U_DP_RAM : entity work.DP_RAM
  PORT map (
    clka     => i_ad_clk,
    wea      => s_ad_wr,
    addra    => s_ad_arddr,
    dina     => "0000" & s_ad_din_ave_d,
    douta    => open,

    clkb     => i_sys_clk,
    web      => "0",
    addrb    => s_buffer_add,
    dinb     => (others=>'0'),
    doutb    => s_buffer_dout
  );

  -- us
  process(i_sys_clk) is
  begin
    if rising_edge(i_sys_clk) then
      o_burst_data_en <= i_local_burst_rd;
      if (i_buffer_add_reset(0) = '1') then
        s_buffer_add    <= (others=>'0');
        s_burst_data_us <= (others => '0');
      elsif (i_local_burst_rd = '1' and i_local_burst_index = '0') then
        s_buffer_add <= s_buffer_add + '1';
        if (i_burst_type(0) = '0') then
          -- s_burst_data_us <= s_burst_data_us + '1';
          s_burst_data_us(11 downto 0) <= s_burst_data_us(11 downto 0) + '1';
        else
          s_burst_data_us <= s_buffer_dout;
        end if;
      elsif (i_local_burst_rd_end = '1' and i_local_burst_index = '0') then
        s_buffer_add <= s_buffer_add - '1';
        -- s_burst_data_us <= s_burst_data_us - '1';
        s_burst_data_us(11 downto 0) <= s_burst_data_us(11 downto 0) - '1';
      end if;
    end if;
  end process;

  -- imu
  process(i_sys_clk) is
  begin
    if rising_edge(i_sys_clk) then
      if (i_buffer_add_reset(1) = '1') then
        s_burst_data_imu <= x"FFFF";
      elsif (i_local_burst_rd = '1' and i_local_burst_index = '1') then
        s_burst_data_imu(11 downto 0) <= s_burst_data_imu(11 downto 0) - '1';
      elsif (i_local_burst_rd_end = '1' and i_local_burst_index = '1') then
        s_burst_data_imu(11 downto 0) <= s_burst_data_imu(11 downto 0) + '1';
      end if;
    end if;
  end process;

  o_burst_data          <= s_burst_data_imu when (i_local_burst_index = '1') else s_burst_data_us;
  o_burst_us_req        <= s_burst_us_req;
  o_burst_imu_req       <= s_burst_imu_req;

end Behavioral;