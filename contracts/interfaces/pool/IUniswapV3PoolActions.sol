// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool 初始时交易池价格（sqrt[amountToken1/amountToken0]）
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position 添加给定tick位置的流动性
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// 调用者回调IUniswapV3MintCallback， 回调前需要支付fee， token0/token1数量依赖于tick的范围，流动性的数量的和当前的价格；
    /// @param recipient The address for which the liquidity will be created 创建流动性接收者地址
    /// @param tickLower The lower tick of the position in which to add liquidity tick下限
    /// @param tickUpper The upper tick of the position in which to add liquidity tick上限
    /// @param amount The amount of liquidity to mint 挖取的流动性数量
    /// @param data Any data that should be passed through to the callback 回调数据
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    ///  挖取的token0的流动性数量
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// 挖取的token1的流动性数量
    /// 
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position 收集给定位置的token；矫正token拥有的交易pair token的数量； 提取手续费
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// 不会重新计算通过mint，burn任何数量的流动性fee；收集者必须为位置的拥有者。为了仅仅退款token0和token1，amount0Requested和
    /// amount1Requested必须设置为0。为了退款拥有的所有的tokens，必须传大于实际token的数量。
    /// @param recipient The address which should receive the fees collected  接受收集fee的接收者
    /// @param tickLower The lower tick of the position for which to collect fees 收集费用的tick下限
    /// @param tickUpper The upper tick of the position for which to collect fees 收集费用的tick上限
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed 需要退款的token0费用
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed 需要退款的token1费用
    /// @return amount0 The amount of fees collected in token0  token0费用收集的数量
    /// @return amount1 The amount of fees collected in token1 token1费用收集的数量
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    ///  销毁给定tick下的流动性
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// 可以用于数量为0情况的费用重新计算
    /// @dev Fees must be collected separately via a call to #collect
    ///  Fees必须使用collect单独收集
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn 需要销毁的流动性数量
    /// @return amount0 The amount of token0 sent to the recipient 发送给接收者的token0数量
    /// @return amount1 The amount of token1 sent to the recipient 发送给接收者的token1数量
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0  token0, token1之间的swap操作
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// 调用者回调形式IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap 接收者
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    ///  true，token0->token1; false,token1->token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// swap的数量，
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// sqrtPriceLimitX96为sqrt价格限制。如果为token0->token1，价格不能低于sqrtPriceLimitX96价格；
    /// 如果为token1->token0, 在swap后价格不能大于此价格
    /// @param data Any data to be passed through to the callback 回调数据
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// 交易池token0变化的数量，当为负值，则为精确值，为正值，为最小值；
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    /// 交易池token1变化的数量，当为负值，则为精确值，为正值，为最小值；
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// 接收token0或token1，并在回调中支付相关的费用
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// 调用者回调形式IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// 可以用于按比例捐赠底层token
    /// @param recipient The address which will receive the token0 and token1 amounts 接收token0,1的地址
    /// @param amount0 The amount of token0 to send 发送的token0数量
    /// @param amount1 The amount of token1 to send 发送的token1数量
    /// @param data Any data to be passed through to the callback 回调数据
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// 增加池存储的最大价格和流动性观察信息
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// 如果pool中的oracle几点索引，已经大于当前参数observationCardinalityNext， 则是此方法为一个空操作
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    /// 交易池需要存储的最小观察者基点位置
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}
