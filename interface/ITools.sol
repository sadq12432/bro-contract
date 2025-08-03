// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface ITools {
    function updateBalanceCake(address token,address target) external;
    function updateBalanceUser(address token,address target) external;
    function updateMiningOutput(address token,address target) external;
    function updateMerit(address target,uint amountIn,uint action) external;
}
