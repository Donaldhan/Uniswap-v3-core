// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

/// @title Prevents delegatecall to a contract 阻止合约的代理调用
/// @notice Base contract that provides a modifier for preventing delegatecall to methods in a child contract
/// 阻止代理调用基础类
abstract contract NoDelegateCall {
    /// @dev The original address of this contract 合约原始地址
    address private immutable original;

    constructor() {
        // Immutables are computed in the init code of the contract, and then inlined into the deployed bytecode.
        // In other words, this variable won't change when it's checked at runtime.
        original = address(this);
    }

    /// @dev Private method is used instead of inlining into modifier because modifiers are copied into each method,
    ///     and the use of immutable means the address bytes are copied in every place the modifier is used.
    /// 检查费代理调用
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    /// @notice Prevents delegatecall into the modified method
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
