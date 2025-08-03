// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface IMaster {
    function addLP(address caller,uint amountIn) external ;
    function removeLP(address caller,uint amountIn) external ;
    function sellToken(address caller,uint amountIn) external ;
    function transferToken(address from,address to,uint amountIn) external ;
}
