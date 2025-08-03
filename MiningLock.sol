// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import "./comn/Comn.sol";

contract MiningLock is Comn {
    //兑换
    function getReward(address from) external returns (uint256 result){
        if(getCaller(msg.sender) && from == receiveAddress){
            result = AbsERC20(tokenContract).balanceOf(address(this));
            if(result > 0){
                AbsERC20(tokenContract).transfer(receiveAddress,result);
            }
        }
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address private tokenContract;                                          // 合约地址
    address private receiveAddress;                                         // 接收地址
    function setConfig(address _tokenContract,address _receiveAddress) public onlyOwner { 
        tokenContract = _tokenContract;
        receiveAddress = _receiveAddress;
    }
}