pragma solidity ^0.8.24;

interface IMaster {
    function sellToken(address from, uint256 amount) external;
    function transferToken(address from, address to, uint256 amount) external;
    function transferBefore(address from, address to, uint256 amount) external returns (uint256 amountBefore);
    function transferAfter(address from, address to, uint256 amount, uint256 amountBefore) external;
    function getMiningLPReward(address account) external view returns (uint256);
    function getMiningNodeReward(address account) external view returns (uint256);
    function addLiquidity(address caller, uint256 amountBnb) external returns (bool);
}