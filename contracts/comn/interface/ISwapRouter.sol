// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

//Pancake交易路由
interface ISwapRouter{
    struct ExactOutputParams {
        bytes path;              //交易路径
        address recipient;       //收款地址
        uint256 amountOut;       //指定输出的token数量
        uint256 amountInMaximum; //输入token的最大数量
    }
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}