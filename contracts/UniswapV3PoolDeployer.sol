// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3PoolDeployer.sol';

import './UniswapV3Pool.sol';

contract UniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    //交易池采纳数
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        //创建交易池
        //CREATE2 指令的具体解释可以参考：EIP-1014。solidity 在 0.6.2 版本后在语法层面支持了 CREATE2. 如果使用更低的版本，可以参考 Uniswap v2 的代码实现同样的功能。
        //https://docs.soliditylang.org/en/latest/control-structures.html#salted-contract-creations-create2
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}
