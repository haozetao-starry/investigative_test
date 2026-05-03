//
module da_wave_send(
    input                 clk         ,  //时钟
    input                 rst_n       ,  //复位信号，低电平有效
    input        [7:0]    rd_data     ,  //外部(比如DDS)送来的数据

    //DA芯片接口
    output                da_clk      ,  //DA(AD9708)驱动时钟,最大支持125Mhz时钟
    output       [7:0]    da_data        //输出给DA的数据  
    );

//*****************************************************
//**                    main code
//*****************************************************

//数据rd_data是在clk的上升沿更新的，所以DA芯片在clk的下降沿锁存数据是稳定的时刻
//而DA实际上在da_clk的上升沿锁存数据,所以时钟取反,这样clk的下降沿相当于da_clk的上升沿
//建议在高速设计中用ODDR来输出时钟，目前低速直接取反即可。
assign  da_clk  = ~clk;       
assign  da_data = rd_data;   //将读到的数据赋给DA端口直接输出

endmodule
