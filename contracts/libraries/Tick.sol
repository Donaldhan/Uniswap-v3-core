// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './TickMath.sol';
import './LiquidityMath.sol';

/// @title Tick 包含tick的管理和相关计算
/// @notice Contains functions for managing tick processes and relevant calculations
library Tick {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    // info stored for each initialized individual tick tick信息
    struct Info {
        // the total position liquidity that references this tick 当前tick流动性
        uint128 liquidityGross;
        // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left), tick交叉的流动性网格数量
        int128 liquidityNet;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        //tick范围外的token0， token1增加fee
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        // the cumulative tick value on the other side of the tick tick范围累计的tick值
        int56 tickCumulativeOutside;
        // the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        // 相对于当前tick外的每个流动性单元的seconds，相对平均值
        uint160 secondsPerLiquidityOutsideX128;
        // the seconds spent on the other side of the tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        // 相对于当前tick外的花费的seconds，相对平均值
        uint32 secondsOutside;
        // true iff the tick is initialized, i.e. the value is exactly equivalent to the expression liquidityGross != 0
        // these 8 bits are set to prevent fresh sstores when crossing newly initialized ticks
        // 是否初始化
        bool initialized;
    }

    /// @notice Derives max liquidity per tick from given tick spacing 计算给定tickSpacing下每个tick的最大流动性
    /// @dev Executed within the pool constructor
    /// @param tickSpacing The amount of required tick separation, realized in multiples of `tickSpacing`
    ///     e.g., a tickSpacing of 3 requires ticks to be initialized every 3rd tick i.e., ..., -6, -3, 0, 3, 6, ...
    /// @return The max liquidity per tick
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;//最大tick
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;//最小tick
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;//tick数量
        return type(uint128).max / numTicks;
    }

    /// @notice Retrieves fee growth data 获取在tick范围下的，基于当前tick的费用增长数据
    /// @param self The mapping containing all tick information for initialized ticks  初始tick信息
    /// @param tickLower The lower tick boundary of the position tick下限
    /// @param tickUpper The upper tick boundary of the position tick上限
    /// @param tickCurrent The current tick 当前tick
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0 token0每个流动性单元的全局增加费用
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1 token1每个流动性单元的全局增加费用
    /// @return feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    // 在当期tick范围内的，token0每个流动性单元的增加费用
    /// @return feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    ///  // 在当期tick范围内的，token1每个流动性单元的增加费用
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        //上下限tick信息
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        // calculate fee growth below 最低费用增长下限
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            //当前tick大等于tick下限，则取下限的feeGrowthOutside0/1X128
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            //否则则取feeGrowthGlobal0/1X128与下限的feeGrowthOutside0/1X128差值
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        // calculate fee growth above 最高增加分费用上限
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            //tick小于tick上限，则取上限的feeGrowthOutside0/1X128
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            //否则取feeGrowthGlobal0/1X128与上限的feeGrowthOutside0/1X128差值
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }
        //获取tick区间内的fee，当前tick在区间内，则为上限减下限的feeGrowthOutside0/1X128 
        //否则为，上限+下限的feeGrowthOutside0/1X128-feeGrowthGlobal0/1X128
        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    /// @notice Updates a tick and returns true if the tick was flipped from initialized to uninitialized, or vice versa
    /// 更新tick，如果tick从初始化到未初始化， 或者从未初始化到初始化，初始化状态发生变更时，则返回true
    /// @param self The mapping containing all tick information for initialized ticks 包含所有tick信息Map
    /// @param tick The tick that will be updated 更新的tick
    /// @param tickCurrent The current tick 当前tick
    /// @param liquidityDelta A new amount of liquidity to be added (subtracted) when tick is crossed from left to right (right to left) 跨tick增加的流动性
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0 token0每个流动性单元增加的全局fee
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1 token1每个流动性单元增加的全局fee
    /// @param secondsPerLiquidityCumulativeX128 The all-time seconds per max(1, liquidity) of the pool 交易池每个流动性max(1, liquidity)的秒速
    /// @param tickCumulative The tick * time elapsed since the pool was first initialized  tick累计时长
    /// @param time The current block timestamp cast to a uint32 当前时间戳
    /// @param upper true for updating a position's upper tick, or false for updating a position's lower tick 是否更新upper tick
    /// @param maxLiquidity The maximum liquidity allocation for a single tick 单个tick允许的最大流动性
    /// @return flipped Whether the tick was flipped from initialized to uninitialized, or vice versa
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        //取当前tick的信息
        Tick.Info storage info = self[tick];
        //增加liquidityGross
        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');
        //状态是否变化
        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {//tick未初始化
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                //tick的feeGrowthOutside0X128取全局feeGrowthGlobal0X128
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                //累计时长
                info.tickCumulativeOutside = tickCumulative;
                //当前时间
                info.secondsOutside = time;
            }
            info.initialized = true;
        }
        //范围流动性
        info.liquidityGross = liquidityGrossAfter;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        //流动性网格数，tick upper，则当前流动性网格减少，否则增加
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();
    }

    /// @notice Clears tick data 清除tick数据
    /// @param self The mapping containing all initialized tick information for initialized ticks
    /// @param tick The tick that will be cleared
    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    /// @notice Transitions to next tick as needed by price movement 根据价格变动的需要，过渡到下一个计时点
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param tick The destination tick of the transition 过渡的下一个tick
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0 token0每个流动性单元增加的全局fee
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1 token1每个流动性单元增加的全局fee
    /// @param secondsPerLiquidityCumulativeX128 The current seconds per liquidity 每个流动性的当前seconds
    /// @param tickCumulative The tick * time elapsed since the pool was first initialized   tick累计时长
    /// @param time The current block.timestamp 当前时间戳 
    /// @return liquidityNet The amount of liquidity added (subtracted) when tick is crossed from left to right (right to left)
    /// 当tick跨越时，流动性网格增加或减少的舒朗
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        //更新tick信息
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside = tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }
}
