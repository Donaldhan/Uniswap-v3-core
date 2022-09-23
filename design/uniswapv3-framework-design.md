
# 新特性
集中流动性：集中流动性提高资金的利用效率，提高流程，避免类似V2资金池中的交易对，出现极端的情况，导致池流动性见底；
指定报价区间，及区间步长；流动性提供者可以提供一个武断的价格区间；


灵活的费用：0.05%, 0.30%, and 1%. 流动池创建者，可以指定费用，同时UNI governance可以添加其他的费用到费用集；

Improved Price Oracle：提供用户查询最近价格，不依赖与TWAP（ time-weighted average price (TWAP)）的checkpoint值；

Liquidity Oracle:提供基于时间的平均流动性预言机合约；


# 架构变更
* 多流动池模式，每个交易对可以一个池，也可以多个交易对多个池；V2所有的交易对都在一个池；
* 交易token不在单单支持ERC20， 拓展至非同质化token； 在Uniswap periphery创建交易池，可以对ERC20进行包装；
* governance：每个池有一个owner，可以支持tick space，同时可以设置没有个tick的fee，一旦设置不可改变；
* price oracle升级；

## ORACLE UPGRADES
v2用户如果需要计算某个period的TWAP，需要追踪从period开始到结束的checkpoint，V3中不在需要追踪检查点，
可以获取最近period的TWAP，V3会log这些price的checkpoint，允许用户计算TWAP算术平均值；

Oracle Observations：在v2只会保存最近区块的价格检查点，用户需要机制拉取以前区块的价格点进行统计。v3中，所有的价格点将会保存一个环形价格检查点中，
，环形中最大可以容纳65,536 checkpoints，当新的检查点产生时，环形中的检查点没有slot，则老的slot的将会被覆盖；

Geometric Mean Price Oracle：V2中，交易对的token是单独跟踪的，没有关联性，V3将会根据交易对的在tick中随时间的token price ratio，计算相应的TWAP；

Liquidity Orace：v3同时每个区块基于秒级的seconds-weighted accumulator, 用于分配流动性奖励；



# 集中流动性实现
1. 将流动池的tick化，每个tick粒度，默认为0.01；pool将会追踪没有tick的每秒的sqrt价格；在初始化时，tick没有暂用的情况下，可以初始化；
2. pool初始化时，会设置tickSpacing，只有tickSpacing允许的范围内，才能添加到pool中，比如如果tickSpacing设为2,则(...-4, -2, 0, 2, 4...)形式的tick才可以初始化；
3. 为了确保正确数量的流动性的加入和退出，pool合约将会追踪pool的全局状态，每个tick及没有位置的状态；

## 全局状态


**Type Variable Name Notation**

* uint128 liquidity 𝐿
* uint160 sqrtPriceX96 sqrt(𝑃)
* int24 tick 𝑖𝑐
* uint256 feeGrowthGlobal0X128 𝑓𝑔,0
* uint256 feeGrowthGlobal1X128 𝑓𝑔,1
* uint128 protocolFees.token0 𝑓𝑝,0
* uint128 protocolFees.token1 𝑓𝑝,1


pair(token x， token y) :

L=sqrt(xy);  
sqrt(p)=sqrt(y/x);  


x=L/sqrt(p);  
y=L/sqrt(p);  


tick(ic)= log(sqrt[basePrice]^sqrt[p]);
 

我们使用L和sqrt(p)跟踪流动性，主要是因为在每个tick，任何时间swap的产生，将会导致sqrt(p)的变动；

[𝑓𝑔,0-𝑓𝑔,1]为swap的全局费用区间, 收费时，以(0.0001%)为基点进行收费；


[𝑓𝑝,0-𝑓𝑝,1]为协议费用区间，具体到交易池；





# TODO
6.3 Tick-Indexed State






# 附
[Uniswap v2-core](https://github.com/Donaldhan/v2-core)     
[Uniswap v2-periphery](https://github.com/Donaldhan/v2-periphery)  
[Uniswap lib](https://github.com/Donaldhan/solidity-lib)    
[一文看懂Uniswap和Sushiswap](https://zhuanlan.zhihu.com/p/226085593)   
[Uniswap深度科普](https://zhuanlan.zhihu.com/p/380749685)    
[去中心化交易所：Uniswap v2白皮书中文版](https://zhuanlan.zhihu.com/p/255190320)   
[Uniswap v3 设计详解](https://zhuanlan.zhihu.com/p/448382469)   
[Uniswap V3 到底是什么鬼？一文带你了解V3新特性](https://zhuanlan.zhihu.com/p/359732262)  
[Uniswap v3 详解（一）：设计原理](https://liaoph.com/uniswap-v3-1/) 
[Uniswap V3 白皮书](https://uniswap.org/whitepaper-v3.pdf) 
[uniswap-v3 blog](https://uniswap.org/blog/uniswap-v3/) 

