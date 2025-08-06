// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface IPancakeRouterV2 {
    function WETH() external pure returns (address);
    
    //添加LP
    function addLiquidity(address tokenA,address tokenB,uint amountADesired,uint amountBDesired,uint amountAMin,uint amountBMin,address to,uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
    //移除LP
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB);
    
    //交换:用 ERC20 兑换 ERC20，但支付的数量是指定的，而兑换回的数量则是未确定的
    function swapExactTokensForTokens(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts);
    //交换:用 ERC20 兑换 ERC20，但支付的数量是指定的，而兑换回的数量则是未确定的，支持转账时扣费
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external;
    //交换:用 ERC20 兑换 ERC20，但支付的数量是未确定的，而兑换回的数量则是指定的
    function swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    
    //根据给定的两个 token 的储备量和其中一个 token 数量，计算得到另一个 token 等值的数值
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    //根据给定的两个 token 的储备量和输入的 token 数量，计算得到输出的 token 数量，该计算会扣减掉 0.3% 的手续费
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    //根据给定的两个 token 的储备量和输出的 token 数量，计算得到输入的 token 数量，该计算会扣减掉 0.3% 的手续费
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    //根据兑换路径和输入数量，计算得到兑换路径中每个交易对的输出数量(解:比如path为[A,B,C],则会先将A兑换成B,再将B兑换成C.返回值则是一个数组,第一个元素是A的数量,即amountIn,而第二个元素则是兑换到的代币B的数量,最后一个元素则是最终要兑换得到的代币C的数量.)
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    //根据兑换路径和输出数量，计算得到兑换路径中每个交易对的输入数量
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}
