// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IMining} from "./interface/IMining.sol";
import {MiningBurnLib} from "./comn/library/MiningBurnLib.sol";
import {Comn} from "./comn/Comn.sol";

contract MiningBurn is Comn,IMining {
    using MiningBurnLib for MiningBurnLib.MiningData;
    
    MiningBurnLib.MiningData private miningData;

    // 更新挖矿奖励
    modifier updateReward(address account) {
        miningData.updateReward(account);
        _;
    }

    // 单币总产量
    function rewardPerToken() public view returns (uint256) {
        return miningData.rewardPerToken();
    }

    // 最后一个区间的总产币量
    function rewardLastToken() public view returns (uint256) {
        return miningData.rewardLastToken();
    }

    function _earned(address account, uint _rewardPerTokenStored) public view returns (uint256) {
        return miningData._earned(account, _rewardPerTokenStored);
    }

    function getNowTime() public view returns (uint256) {
        return miningData.getNowTime();
    }

    /*---------------------------------------------------接口-----------------------------------------------------------*/
    function earned(address account) public view virtual returns (uint256) {
        return miningData.earned(account);
    }

    function getReward(address account) public isCaller virtual returns (uint256) {
        return miningData.getReward(account);
    }

    function stake(address account,uint number) public isCaller virtual returns (uint256 result){
        return miningData.stake(account, number);
    }

    function withdraw(address account,uint number) public isCaller virtual {
        miningData.withdraw(account, number);
    }

    function updateOutput(uint cakePoolAmount) external isCaller virtual returns(uint outputToWei){
        if(getCaller(msg.sender) || msg.sender == getOwner()){
            return miningData.updateOutput(cakePoolAmount);
        }
    }

    function getTotalOutput() public view virtual returns (uint256) { return miningData.getTotalOutput(); }
    function getStakeUser(address account) public view virtual returns (uint256) { return miningData.getStakeUser(account); }
    function getStakeAdmin(address account) public view virtual returns (uint256) { return miningData.getStakeAdmin(account); }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    function setConfig(uint _outputMin,uint[] memory _upScale,uint[] memory _downScale) external onlyOwner {
        miningData.setConfig(_outputMin, _upScale, _downScale);
    }

    function setEndTime(uint _miningEndTime) external onlyOwner {
        miningData.setEndTime(_miningEndTime);
    }

    function setOutput(uint outputToWei) external onlyOwner {
        miningData.setOutput(outputToWei);
    }

    function setStake(address account,uint number) external onlyOwner {
        miningData.setStake(account, number);
    }

    // 公共访问器函数
    function updateTime() public view returns (uint256) { return miningData.updateTime; }
    function rewardPerTokenStored() public view returns (uint256) { return miningData.rewardPerTokenStored; }
    function userRewardPerTokenPaid(address account) public view returns (uint256) { return miningData.userRewardPerTokenPaid[account]; }
    function rewards(address account) public view returns (uint256) { return miningData.rewards[account]; }
    function miningEndTime() public view returns (uint256) { return miningData.miningEndTime; }
    function miningRateSecond() public view returns (uint256) { return miningData.miningRateSecond; }
}