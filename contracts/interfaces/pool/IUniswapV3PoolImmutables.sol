// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that never changes 交易池状态常量，一旦设置，永久不可变
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address 交易池工厂地址
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address 交易池token0
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address 交易池token1
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6 交易池费用
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing 交易池tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    /**
     * 在每个tick范围内，可以使用的最大流动性数量
     * 此参数用于tick增强，防止在任何point的uint128的溢出，同时防止在添加范围流动性时，流动性out-of-range
     */
    function maxLiquidityPerTick() external view returns (uint128);
}
