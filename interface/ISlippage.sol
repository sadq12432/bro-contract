// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface ISlippage {
    function direction(address from, address to) external view returns(uint256);
    function slippage(address from, address to, uint256 amount) external view returns(uint256);
    function grant(address from, address to, uint256 amount) external returns(bool);
}
