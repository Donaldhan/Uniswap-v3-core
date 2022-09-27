// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './FullMath.sol';
import './SqrtPriceMath.sol';

/// @title Computes the result of a swap within ticks 计算给定tick范围的swap结果
/// @notice Contains methods for computing the result of a swap within a single tick price range, i.e., a single tick.
library SwapMath {
    /// @notice Computes the result of swapping some amount in, or amount out, given the parameters of the swap
     /// 在给定swap参数下，计算swap 输入或输出的数量结果
    /// @dev The fee, plus the amount in, will never exceed the amount remaining if the swap's `amountSpecified` is positive
    /// 如果amountSpecified为正值， 费用加输入的token数量，不能超过剩余的储备量
    /// @param sqrtRatioCurrentX96 The current sqrt price of the pool 当前交易池流动性价格
    /// @param sqrtRatioTargetX96 The price that cannot be exceeded, from which the direction of the swap is inferred  目标流动性价格
    /// @param liquidity The usable liquidity 可用的流动性
    /// @param amountRemaining How much input or output amount is remaining to be swapped in/out  swap token剩余量，储备量
    /// @param feePips The fee taken from the input amount, expressed in hundredths of a bip 
    /// @return sqrtRatioNextX96 The price after swapping the amount in/out, not to exceed the price target 在swap后的流动性价格
    /// @return amountIn The amount to be swapped in, of either token0 or token1, based on the direction of the swap 需要输入的token数量
    /// @return amountOut The amount to be received, of either token0 or token1, based on the direction of the swap swap出的token数量
    /// @return feeAmount The amount of input that will be taken as a fee 费用
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (
            uint160 sqrtRatioNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
        bool exactIn = amountRemaining >= 0;

        if (exactIn) {
            //先计算当价格移动到交易区间边界时，所需要的手续费
            uint256 amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            //基于当前流动性，目标价格与当前价格，获取需要输入的token数量
            amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
            if (amountRemainingLessFee >= amountIn) sqrtRatioNextX96 = sqrtRatioTargetX96;//流动性充足，则目标流动性价格有效
            else
            //不足则获取剩余费用的价格
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
        } else {
              //基于当前流动性，目标价格与当前价格，获取输出的token数量
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);
            if (uint256(-amountRemaining) >= amountOut) sqrtRatioNextX96 = sqrtRatioTargetX96;//流动性充足，则目标流动性价格有效
            else
             //不足则获取剩余费用的价格
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
        }
        //是否可以提取或输入充足的token数量
        bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;

        // get the input/output amounts 获取输入和输出的token数量
        if (zeroForOne) {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // cap the output amount to not exceed the remaining output amount out token不能超过储备量
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
            // we didn't reach the target, so take the remainder of the maximum input as fee
            //储备量充足，剩余储备量作为fee
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
