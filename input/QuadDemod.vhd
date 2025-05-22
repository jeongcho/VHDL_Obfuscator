library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.pkg_util.all;

-- m_step = round(f0/fs*2^22)

entity QuadDemod is
    Port (  
        m_clk       :   in  std_logic;
        m_din       :   in  std_logic_vector(13 downto 0);
        m_freq      :   in  std_logic_vector(21 downto 0);
        m_dout_en   :   out std_logic;
        m_dout_i    :   out std_logic_vector(15 downto 0);
        m_dout_q    :   out std_logic_vector(15 downto 0)
    );
end QuadDemod;

architecture Behavioral of QuadDemod is

    component sincos is
    Port (  m_clk           :   in  std_logic;
            m_reset         :   in  std_logic;
            m_ce            :   in  std_logic;
            m_step          :   in  std_logic_vector(21 downto 0);
            m_cos           :   out std_logic_vector(15 downto 0);
            m_sin           :   out std_logic_vector(15 downto 0));
    end component;
    
    component sincosNew is
    Port (  m_clk           :   in  std_logic;
            m_step          :   in  std_logic_vector(21 downto 0);
            m_cos           :   out std_logic_vector(15 downto 0);
            m_sin           :   out std_logic_vector(15 downto 0));
    end component;    
    
    COMPONENT ip_mult_s14_s16
    PORT (
        CLK     : IN STD_LOGIC;
        A       : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
        B       : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        P       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
    END COMPONENT;
    
    COMPONENT ip_fifo_adc_din
    PORT (
        wr_clk : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
    );
    END COMPONENT;    
    
    COMPONENT ip_quad_lpf
    PORT (
        aclk                : IN STD_LOGIC;
        s_axis_data_tvalid  : IN STD_LOGIC;
        s_axis_data_tready  : OUT STD_LOGIC;
        s_axis_data_tdata   : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid  : OUT STD_LOGIC;
        m_axis_data_tdata   : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT;    

    signal  s_din           :   std_logic_vector(13 downto 0);
    signal  s_cos           :   std_logic_vector(15 downto 0);
    signal  s_sin           :   std_logic_vector(15 downto 0);
    signal  s_sin_n         :   std_logic_vector(15 downto 0);
    signal  s_dout_i        :   std_logic_vector(15 downto 0);
    signal  s_dout_q        :   std_logic_vector(15 downto 0);
    
    signal  s_fir_din       :   STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal  s_fir_dout_en   :   STD_LOGIC;
    signal  s_fir_dout      :   STD_LOGIC_VECTOR(47 DOWNTO 0);    
    signal  s_freq          :   std_logic_vector(21 downto 0);
    signal  s_fir_ready     :   std_logic;

    signal  s_quad_dout_en  :   STD_LOGIC;
    signal  s_quad_dout_i   :   std_logic_vector(15 downto 0);
    signal  s_quad_dout_q   :   std_logic_vector(15 downto 0);
    
    COMPONENT ila_qmod
    PORT (  clk     : IN STD_LOGIC;
            probe0  : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
            probe1  : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
            probe2  : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
            probe3  : IN STD_LOGIC_VECTOR(15 DOWNTO 0));
    END COMPONENT  ;    
    
    signal  s_cosOld        :   std_logic_vector(15 downto 0);
    signal  s_sinOld        :   std_logic_vector(15 downto 0);    
    signal  s_cosNew        :   std_logic_vector(15 downto 0);
    signal  s_sinNew        :   std_logic_vector(15 downto 0);     

begin


--    -- ila_qdmod

--    inst_ila_qdmod : ila_qmod
--    PORT MAP (  clk     => m_clk,
--                probe0  => s_cos,
--                probe1  => s_sin,
--                probe2  => s_cosNew,
--                probe3  => s_sinNew);    
        
  
--    U_sincos : sincos 
--    Port map(   m_clk           => m_clk    ,
--                m_reset         => '0'  ,
--                m_ce            => '1',
--                m_step          => m_freq   ,
--                m_cos           => s_sinNew    ,       
--                m_sin           => s_cosNew    );
                
                
    U_sincosNew : sincosNew 
    Port map(   m_clk           => m_clk    ,
                m_step          => m_freq   ,
                m_cos           => s_sin    ,       
                m_sin           => s_cos    );         
                
    
    inst_i_mult : ip_mult_s14_s16
    PORT map(
        CLK     => m_clk,
        A       => m_din,
        B       => s_cos,
        P       => s_dout_i
    );
    
    inst_q_mult : ip_mult_s14_s16
    PORT map(
        CLK     => m_clk,
        A       => m_din,
--        B       => s_sin,     --  @ 50 MHz
        B       => s_sin_n,     --  @ 40 MHz
        P       => s_dout_q
    );    
    
    s_sin_n <= not(s_sin) + '1';
    
    inst_ip_quad_lpf : ip_quad_lpf
    PORT map(
        aclk                => m_clk,
        s_axis_data_tvalid  => '1',
        s_axis_data_tready  => s_fir_ready,
        s_axis_data_tdata   => s_fir_din,
        m_axis_data_tvalid  => s_fir_dout_en,
        m_axis_data_tdata   => s_fir_dout
    );
    
    s_fir_din   <= s_dout_i & s_dout_q;

    process(m_clk)
    begin
        if rising_edge(m_clk) then
            s_quad_dout_en   <= s_fir_dout_en;
            s_quad_dout_i    <= sat(rnd(s_fir_dout(47 downto 24),5),3);
            s_quad_dout_q    <= sat(rnd(s_fir_dout(23 downto  0),5),3);
        end if;
    end process;     
    
    process(m_clk)
    begin
        if rising_edge(m_clk) then
            m_dout_en   <= s_quad_dout_en   ;
            m_dout_i    <= s_quad_dout_i    ;
            m_dout_q    <= s_quad_dout_q    ;
        end if;
    end process;          

end Behavioral;
