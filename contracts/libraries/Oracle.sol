// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

/// @title Oracle
/// @notice Provides price and liquidity data useful for a wide variety of system designs 提供价格和流动性预测；
/// @dev Instances of stored oracle data, "observations", are collected in the oracle array
/// Every pool is initialized with an oracle array length of 1. Anyone can pay the SSTOREs to increase the
/// maximum length of the oracle array. New slots will be added when the array is fully populated.
/// 存储oracle观察点的实例。 每个交易池初始化时，orcle长度为1。任何人可以增加oracle的长度。当数组满时，将会添加新的slot；
/// Observations are overwritten when the full length of the oracle array is populated.
/// 当oracl数组满时，将会重新观察点
/// The most recent observation is available, independent of the length of the oracle array, by passing 0 to observe()
/// 最近的观察点是可用的，独立与oracl数组的长度，通过传0给observe方法
library Oracle {
    //观察点
    struct Observation {
        // the block timestamp of the observation 观察点区块时间戳
        uint32 blockTimestamp;
        // the tick accumulator, i.e. tick * time elapsed since the pool was first initialized 累计时间
        int56 tickCumulative;
        // the seconds per liquidity, i.e. seconds elapsed / max(1, liquidity) since the pool was first initialized
        // 从交易池初始化开始，每个流动性经过的时间seconds
        uint160 secondsPerLiquidityCumulativeX128;
        // whether or not the observation is initialized 观察点是否初始化
        bool initialized;
    }

    /// @notice Transforms a previous observation into a new observation, given the passage of time and the current tick and liquidity values
    /// 在给定时间，当前tick和流动性的情况下，基于先前的观察点，生成一个新的观察点
    /// @dev blockTimestamp _must_ be chronologically equal to or greater than last.blockTimestamp, safe for 0 or 1 overflows
    /// 时间必须大于last.blockTimestamp
    /// @param last The specified observation to be transformed 上个观察带你
    /// @param blockTimestamp The timestamp of the new observation 新的观察点区块时间戳
    /// @param tick The active tick at the time of the new observation 新的观察点激活的tick
    /// @param liquidity The total in-range liquidity at the time of the new observation  在新观察点时间内总的流动性
    /// @return Observation The newly populated observation 新的观察点
    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns (Observation memory) {
        //观察点时间间隔
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * delta,//累计的tick时间
                secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)), //每个流动性使用的时间seconds
                initialized: true
            });
    }

    /// @notice Initialize the oracle array by writing the first slot. Called once for the lifecycle of the observations array
    /// 通过写第一个slot，初始化oracle 数组；在观察点声明周期的开始点调用
    /// @param self The stored oracle array 
    /// @param time The time of the oracle initialization, via block.timestamp truncated to uint32 oracle初始化的时间戳
    /// @return cardinality The number of populated elements in the oracle array oracle数组元素舒朗
    /// @return cardinalityNext The new length of the oracle array, independent of population 新的oracle数组长度
    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({
            blockTimestamp: time,
            tickCumulative: 0,
            secondsPerLiquidityCumulativeX128: 0,
            initialized: true
        });
        return (1, 1);
    }

    /// @notice Writes an oracle observation to the array 写oracle观察点到数组
    /// @dev Writable at most once per block. Index represents the most recently written element. cardinality and index must be tracked externally.
    /// 在出块时，写入。Index表示最近写入的索引，cardinality and index用于内部追踪
    /// If the index is at the end of the allowable array length (according to cardinality), and the next cardinality
    /// is greater than the current one, cardinality may be increased. This restriction is created to preserve ordering.
    ///  如果索引在数组允许长度的尾部，cardinality将会增加，前提条件是先前的观察点已经创建
    /// @param self The stored oracle array
    /// @param index The index of the observation that was most recently written to the observations array 最近写入的观察点索引
    /// @param blockTimestamp The timestamp of the new observation 新的观察点时间戳
    /// @param tick The active tick at the time of the new observation 观察点tick
    /// @param liquidity The total in-range liquidity at the time of the new observation 新观察点的流动性
    /// @param cardinality The number of populated elements in the oracle array 数组元素个数 
    /// @param cardinalityNext The new length of the oracle array, independent of population
    /// @return indexUpdated The new index of the most recently written element in the oracle array 写入的观察点索引
    /// @return cardinalityUpdated The new cardinality of the oracle array oracle数组新基点cardinalityUpdated
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // early return if we've already written an observation this block 已经写入
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // if the conditions are right, we can bump the cardinality 观察点基点总数
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }
        //观察点索引
        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, blockTimestamp, tick, liquidity);
    }

    /// @notice Prepares the oracle array to store up to `next` observations 准备存储观察点
    /// @param self The stored oracle array
    /// @param current The current next cardinality of the oracle array 当前oracle数组的cardinalityNext
    /// @param next The proposed next cardinality which will be populated in the oracle array 提议的cardinalityNext
    /// @return next The next cardinality which will be populated in the oracle array 返回最后的cardinalityNext
    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        require(current > 0, 'I');
        // no-op if the passed next value isn't greater than the current next value 在当前基点范围内
        if (next <= current) return current;
        // store in each slot to prevent fresh SSTOREs in swaps
        // this data will not be used because the initialized boolean is still false
        //增加oracle数组观察点数量
        for (uint16 i = current; i < next; i++) self[i].blockTimestamp = 1;
        return next;
    }

    /// @notice comparator for 32-bit timestamps 比较32的时间戳
    /// @dev safe for 0 or 1 overflows, a and b _must_ be chronologically before or equal to time
    /// @param time A timestamp truncated to 32 bits
    /// @param a A comparison timestamp from which to determine the relative position of `time` 比较时间戳的相对位置
    /// @param b From which to determine the relative position of `time` 
    /// @return bool Whether `a` is chronologically <= `b`
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust a,b 都小于时间戳
        if (a <= time && b <= time) return a <= b;
        
        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }

    /// @notice Fetches the observations beforeOrAt and atOrAfter a target, i.e. where [beforeOrAt, atOrAfter] is satisfied.
    /// The result may be the same observation, or adjacent observations.
     /// 抓取给定目标的前驱和后继观察点，有可能一致，有可能是邻近观察点
    /// @dev The answer must be contained in the array, used when the target is located within the stored observation
    /// boundaries: older than the most recent observation and younger, or the same age as, the oldest observation
    /// @param self The stored oracle array
    /// @param time The current block.timestamp 当前时间戳
    /// @param target The timestamp at which the reserved observation should be for 目标时间戳
    /// @param index The index of the observation that was most recently written to the observations array 最近观察点的索引
    /// @param cardinality The number of populated elements in the oracle array 当前oracle中观察点数量
    /// @return beforeOrAt The observation recorded before, or at, the target 目标或先驱观察点
    /// @return atOrAfter The observation recorded at, or after, the target 目标或后继观察点
    function binarySearch(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // oldest observation 最老的观察点
        uint256 r = l + cardinality - 1; // newest observation 最新观察点
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % cardinality];

            // we've landed on an uninitialized tick, keep searching higher (more recently) 跳过没有初始化的观察点
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // check if we've found the answer! 找到targetAtOrAfter
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    /// @notice Fetches the observations beforeOrAt and atOrAfter a given target, i.e. where [beforeOrAt, atOrAfter] is satisfied
    /// @dev Assumes there is at least 1 initialized observation.
    ///  抓取给定目标的前驱和后继观察点，有可能一致，有可能是邻近观察点
    /// @param self The stored oracle array
    /// @param time The current block.timestamp 当前区块时间戳
    /// @param target The timestamp at which the reserved observation should be for 目标时间戳
    /// @param tick The active tick at the time of the returned or simulated observation
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param liquidity The total pool liquidity at the time of the call
    /// @param cardinality The number of populated elements in the oracle array
    /// @return beforeOrAt The observation which occurred at, or before, the given timestamp
    /// @return atOrAfter The observation which occurred at, or after, the given timestamp
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // optimistically set before to the newest observation
        beforeOrAt = self[index];

        // if the target is chronologically at or after the newest observation, we can early return；目标在最新观察点或者之后
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {//为目标观察点
                // if newest observation equals target, we're in the same block, so we can ignore atOrAfter 最新观察者为目标
                return (beforeOrAt, atOrAfter);
            } else {
                // otherwise, we need to transform
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidity));
            }
        }

        // now, set before to the oldest observation
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // ensure that the target is chronologically at or after the oldest observation 确保目标观察点，在最旧的观察点之后
        require(lte(time, beforeOrAt.blockTimestamp, target), 'OLD');

        // if we've reached this point, we have to binary search
        return binarySearch(self, time, target, index, cardinality);
    }

    /// @dev Reverts if an observation at or before the desired observation timestamp does not exist.
    /// 0 may be passed as `secondsAgo' to return the current cumulative values.
    /// If called with a timestamp falling between two observations, returns the counterfactual accumulator values
    /// at exactly the timestamp between the two observations.
    /// 基于当前区块时间戳，往后推secondsAgo秒的观察点的累计时间tickCumulative和每个流动性运行的时间secondsPerLiquidityCumulativeX128
    /// @param self The stored oracle array
    /// @param time The current block timestamp 当前时间戳
    /// @param secondsAgo The amount of time to look back, in seconds, at which point to return an observation 后推的秒数secondsAgo
    /// @param tick The current tick
    /// @param index The index of the observation that was most recently written to the observations array 
    /// @param liquidity The current in-range pool liquidity
    /// @param cardinality The number of populated elements in the oracle array
    /// @return tickCumulative The tick * time elapsed since the pool was first initialized, as of `secondsAgo`
    /// 
    /// @return secondsPerLiquidityCumulativeX128 The time elapsed / max(1, liquidity) since the pool was first initialized, as of `secondsAgo`
    /// 
    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
        if (secondsAgo == 0) {//返回最近最新写入的观察点
            Observation memory last = self[index];
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidity);
            return (last.tickCumulative, last.secondsPerLiquidityCumulativeX128);
        }

        uint32 target = time - secondsAgo;//目标时间戳
        //获取给定目标点的前驱和后继观察点
        (Observation memory beforeOrAt, Observation memory atOrAfter) =
            getSurroundingObservations(self, time, target, tick, index, liquidity, cardinality);

        if (target == beforeOrAt.blockTimestamp) {//为前驱观察点
            // we're at the left boundary
            return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
        } else if (target == atOrAfter.blockTimestamp) { //为后继观察点
            // we're at the right boundary
            return (atOrAfter.tickCumulative, atOrAfter.secondsPerLiquidityCumulativeX128);
        } else {
            // we're in the middle 在中间
            uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
            uint32 targetDelta = target - beforeOrAt.blockTimestamp;
            return (
                beforeOrAt.tickCumulative +
                    ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / observationTimeDelta) *
                    targetDelta,
                beforeOrAt.secondsPerLiquidityCumulativeX128 +
                    uint160(
                        (uint256(
                            atOrAfter.secondsPerLiquidityCumulativeX128 - beforeOrAt.secondsPerLiquidityCumulativeX128
                        ) * targetDelta) / observationTimeDelta
                    )
            );
        }
    }

    /// @notice Returns the accumulator values as of each time seconds ago from the given time in the array of `secondsAgos`
    /// @dev Reverts if `secondsAgos` > oldest observation
    ///  批量模式:
    /// 基于当前区块时间戳，往后推secondsAgo秒的观察点的累计时间tickCumulative和每个流动性运行的时间secondsPerLiquidityCumulativeX128
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param secondsAgos Each amount of time to look back, in seconds, at which point to return an observation
    /// @param tick The current tick
    /// @param index The index of the observation that was most recently written to the observations array
    /// @param liquidity The current in-range pool liquidity
    /// @param cardinality The number of populated elements in the oracle array
    /// @return tickCumulatives The tick * time elapsed since the pool was first initialized, as of each `secondsAgo`
    /// @return secondsPerLiquidityCumulativeX128s The cumulative seconds / max(1, liquidity) since the pool was first initialized, as of each `secondsAgo`
    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        require(cardinality > 0, 'I');

        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            (tickCumulatives[i], secondsPerLiquidityCumulativeX128s[i]) = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                liquidity,
                cardinality
            );
        }
    }
}
