// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface IPanel {
    event Notice(address inviter,uint buyUser,uint buyTeam,uint stakeMining,uint stakeNode,uint stakePartner,uint quotaMining,uint outputMining);

    function addLiquidity(address caller,uint amountIn) external payable returns (bool);
    function removeLiquidity(address caller,uint amountIn,address token) external;
    function sellToken(address caller,uint amountIn) external;
    function transferToken(address token,address from,address to,uint amountIn) external returns(uint amountOut);
    function getSwapFlag(address coin) external view returns (bool);
    function getRostSlippage(address target) external view returns (bool);
    function getRostSwap(address target) external view returns (bool);
    function getRostPanel(address target) external view returns (bool);
    function getBalanceFactory(address target) external view returns (uint amountOut);
    function miningMint(address goal,address account, uint256 value) external;
    function miningBurn(address goal,address account, uint256 value) external;
    function transferBefore(address from, address to, uint256 amount) external returns(uint amountUsdt);
    function transferAfter(address from, address to, uint256 amount,uint amountBefore) external;
}
