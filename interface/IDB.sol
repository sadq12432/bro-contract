// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface IDB {
    event BindInviter(address caller, address inviter);
    function setBind(address from,address to) external;
    function getInviter(address caller) external view returns (address inviter);
    function isInviter(address caller) external view returns (bool flag);

    function getSwapFlag(address _coin) external view returns (bool);
    function getSwapLimitMin(address _coin,uint _action) external view returns (uint);
    function getSwapLimitMax(address _coin,uint _action) external view returns (uint);
    function getRostSlippage(address _target) external view returns (bool);
    function getRostSwap(address _target) external view returns (bool);
    function getRostPanel(address _target) external view returns (bool);

    function setSellLastBlock(address coin,uint blockNumber) external;
    function getSellLastBlock(address coin) external view returns (uint blockNumber);

    function getRostBuyWait(address _target) external view returns (bool);

    function getTeamAmount(address target) external view returns (uint amountOut);
    function setTeamAmount(address target,uint amountIn) external;

    function getBuyAmount(address target) external view returns (uint amountOut);
    function setBuyAmount(address target,uint amountIn) external;
}
