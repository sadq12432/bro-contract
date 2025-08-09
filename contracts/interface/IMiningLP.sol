// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

interface IMiningLP {
    function stake(address account, uint256 amount) external;
    function earned(address account) external view returns (uint256);
    function getReward(address account) external returns (uint256);
    function getTotalSupply() external view returns (uint256);
    function getUserBalance(address account) external view returns (uint256);
    function getLastClaimTime(address account) external view returns (uint256);
}