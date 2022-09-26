// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that can change， 交易池状态
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
/**
 * 在每个交易发生时，交易池的状态将有可能发生任意频次的变更；
 */
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// slot0存储交易池一些值，作为外部访问节省gas的暴露接口
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// sqrtPriceX96为交易池当前价格 sqrt(token1/token0) Q64.96；
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// 交易池当前tick，比如最近一次run的tick交易；如果价格在tick的边界，此值不总是等于 to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96)
    /// observationIndex The index of the last oracle observation that was written,
    /// oracle观察者最新写的索引；
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// oracle观察者当前存储在交易池最大基点；
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// oracle观察者下一次更新的最大基点
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// 交易池协议手续费
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// feeProtocol为token1和token0的fee编码；每个费用占4为；token1的fee为高4bit；token0的交易非为低4位
    /// unlocked Whether the pool is currently locked to reentrancy
    /// 交易池当前是否解锁
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// 在整个池声明周期内，每个流动性unit，token0增加的fee
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// 在整个池声明周期内，每个流动性unit，token1增加的fee
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// token0 and token1拥有的协议fee费用
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// 当前可以用的流动性范围
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool 交易池中给定tick的信息
    /// @param tick The tick to look up 交易池tick
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper, 
    /// liquidityGross： 跨越交易tick上下限位置流动性数量
    /// liquidityNet how much liquidity changes when the pool price crosses the tick, 
    /// liquidityNet:当价格跨越tick时，change多少流动性liquidityNet
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside0X128:在tick范围外的，token0的增加费用
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// feeGrowthOutside1X128:在tick范围外的，token1的增加费用
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// tickCumulativeOutside：当前tick范围外的累计的tick数量
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsPerLiquidityOutsideX128:当前tick范围外的每个tick流动性所花费的seconds；
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// secondsOutside: 当前tick范围外的每个tick使用的seconds
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// initialized: tick是否初始化，比如liquidityGross大于0
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// 如果tick初始化，Outside值可以使用，比如liquidityGross大于0
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    /// 另外，这些值是相对先前给定位置快照的值；
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    /// 返回tick初始化bool值的256打包值，更多参见TickBitmap
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key 返回给定位置key的位置信息
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper  位置信息key，为用户者，tick上下限的hash
    /// @return _liquidity The amount of liquidity in the position, 返回给定位置的流动性数量
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// feeGrowthInside0LastX128:token0在key关联的tick内的mint/burn/poke增加的费用
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// feeGrowthInside1LastX128:token1在key关联的tick内的mint/burn/poke增加的费用
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// tokensOwed0:token0在key关联的位置内的mint/burn/poke拥有的数量
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    /// tokensOwed1:token1在key关联的位置内的mint/burn/poke拥有的数量
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index 范围给定索引数据
    /// @param index The element of the observations array to fetch 观察数组索引
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// 你可以使用observe方法获取之前的observation信息，而不是给定索引的observation
    /// @return blockTimestamp The timestamp of the observation, observation的时间戳
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// tickCumulative: 到交易池当前观察时间戳，累计的ticks
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// secondsPerLiquidityCumulativeX128: 到交易池当前观察时间戳，每个流动性范围的seconds
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    /// observation是否初始化
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}
