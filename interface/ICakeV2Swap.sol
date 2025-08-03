// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface ICakeV2Swap {
    function swapTokenToUsdt(uint amountToken,address receiveAddress,address[] memory path,address pair,address slippage) external returns(uint amountUsdtSwap,uint amountUsdtSlippage);
    function swapUsdtToToken(uint amountUsdt,address receiveAddress,address[] memory path,address pair,address slippage) external returns(uint amountTokenSwap,uint amountTokenSlippage);

    function getInToOut(uint amountIn,address[] memory path,address poolPair) external view returns (uint amountOut);
}
