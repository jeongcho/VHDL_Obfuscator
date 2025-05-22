library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

library unisim;
  use unisim.vcomponents.all;
  use work.pkg_util.all;

entity quaddemod is
  port (
    m_clk     : in    std_logic;
    m_din     : in    std_logic_vector(13 downto 0);
    m_freq    : in    std_logic_vector(21 downto 0);
    m_dout_en : out   std_logic;
    m_dout_i  : out   std_logic_vector(15 downto 0);
    m_dout_q  : out   std_logic_vector(15 downto 0)
  );
end entity quaddemod;

architecture behavioral of quaddemod is

  component sincos is
    port (
      m_clk   : in    std_logic;
      m_reset : in    std_logic;
      m_ce    : in    std_logic;
      m_step  : in    std_logic_vector(21 downto 0);
      m_cos   : out   std_logic_vector(15 downto 0);
      m_sin   : out   std_logic_vector(15 downto 0)
    );
  end component;

  component sincosnew is
    port (
      m_clk  : in    std_logic;
      m_step : in    std_logic_vector(21 downto 0);
      m_cos  : out   std_logic_vector(15 downto 0);
      m_sin  : out   std_logic_vector(15 downto 0)
    );
  end component;

  component ip_mult_s14_s16 is port (
      clk : in    std_logic;
      a   : in    std_logic_vector(13 downto 0);
      b   : in    std_logic_vector(15 downto 0);
      p   : out   std_logic_vector(15 downto 0)
    );
  end component;

  component ip_fifo_adc_din is port (
      wr_clk : in    std_logic;
      rd_clk : in    std_logic;
      din    : in    std_logic_vector(13 downto 0);
      wr_en  : in    std_logic;
      rd_en  : in    std_logic;
      dout   : out   std_logic_vector(13 downto 0);
      full   : out   std_logic;
      empty  : out   std_logic
    );
  end component;

  component ip_quad_lpf is port (
      aclk               : in    std_logic;
      s_axis_data_tvalid : in    std_logic;
      s_axis_data_tready : out   std_logic;
      s_axis_data_tdata  : in    std_logic_vector(31 downto 0);
      m_axis_data_tvalid : out   std_logic;
      m_axis_data_tdata  : out   std_logic_vector(47 downto 0)
    );
  end component;

  signal s_din          : std_logic_vector(13 downto 0);
  signal s_cos          : std_logic_vector(15 downto 0);
  signal s_sin          : std_logic_vector(15 downto 0);
  signal s_sin_n        : std_logic_vector(15 downto 0);
  signal s_dout_i       : std_logic_vector(15 downto 0);
  signal s_dout_q       : std_logic_vector(15 downto 0);
  signal s_fir_din      : std_logic_vector(31 downto 0);
  signal s_fir_dout_en  : std_logic;
  signal s_fir_dout     : std_logic_vector(47 downto 0);
  signal s_freq         : std_logic_vector(21 downto 0);
  signal s_fir_ready    : std_logic;
  signal s_quad_dout_en : std_logic;
  signal s_quad_dout_i  : std_logic_vector(15 downto 0);
  signal s_quad_dout_q  : std_logic_vector(15 downto 0);

  component ila_qmod is port (
      clk    : in    std_logic;
      probe0 : in    std_logic_vector(15 downto 0);
      probe1 : in    std_logic_vector(15 downto 0);
      probe2 : in    std_logic_vector(15 downto 0);
      probe3 : in    std_logic_vector(15 downto 0)
    );
  end component;

  signal s_cosold : std_logic_vector(15 downto 0);
  signal s_sinold : std_logic_vector(15 downto 0);
  signal s_cosnew : std_logic_vector(15 downto 0);
  signal s_sinnew : std_logic_vector(15 downto 0);

begin u_sincosnew : sincosnew
    port map (
      m_clk  => m_clk,
      m_step => m_freq,
      m_cos  => s_sin,
      m_sin  => s_cos
    );

  inst_i_mult : ip_mult_s14_s16
    port map (
      clk => m_clk,
      a   => m_din,
      b   => s_cos,
      p   => s_dout_i
    );

  inst_q_mult : ip_mult_s14_s16
    port map (
      clk => m_clk,
      a   => m_din,
      b   => s_sin_n,
      p   => s_dout_q
    );

  s_sin_n <= not(s_sin) + '1';

  inst_ip_quad_lpf : ip_quad_lpf
    port map (
      aclk               => m_clk,
      s_axis_data_tvalid => '1',
      s_axis_data_tready => s_fir_ready,
      s_axis_data_tdata  => s_fir_din,
      m_axis_data_tvalid => s_fir_dout_en,
      m_axis_data_tdata  => s_fir_dout
    );

  s_fir_din <= s_dout_i & s_dout_q;

  process (m_clk) is
  begin if rising_edge(m_clk) then
      s_quad_dout_en <= s_fir_dout_en;
      s_quad_dout_i  <= sat(rnd(s_fir_dout(47 downto 24),
                                5),
                            3);
      s_quad_dout_q  <= sat(rnd(s_fir_dout(23 downto 0),
                                5),
                            3);
    end if;
  end process;

  process (m_clk) is
  begin if rising_edge(m_clk) then
      m_dout_en <= s_quad_dout_en;
      m_dout_i  <= s_quad_dout_i;
      m_dout_q  <= s_quad_dout_q;
    end if;
  end process;

end architecture behavioral;
