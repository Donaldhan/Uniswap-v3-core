// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
/// 仅允许工厂拥有者可以调用
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// 设置交易池协议费用（token0， token1）
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// 收集交易池累计的协议费用
    /// @param recipient The address to which collected protocol fees should be sent 费用接收者
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// 发送token0的最大数量，当仅仅收集token1时，此值为0
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// 发送token1的最大数量，当仅仅收集token0时，此值为0
    /// @return amount0 The protocol fee collected in token0 收集的token0的协议费用
    /// @return amount1 The protocol fee collected in token1 收集的token1的协议费用
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
