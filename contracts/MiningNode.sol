// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import "./comn/Comn.sol";
import "./comn/library/MiningNodeLib.sol";
import "./interface/IMining.sol";

contract MiningNode is Comn,IMining {
    using MiningNodeLib for MiningNodeLib.MiningNodeData;

    MiningNodeLib.MiningNodeData private miningData;


    // 更新挖矿奖励
    modifier updateReward(address account) {
        miningData.updateReward(account);
        _;
    }

    // 单币总产量
    function rewardPerToken() public view returns (uint256) {
        return miningData.rewardPerTokenStored;
    }

    // 最后一个区间的总产币量
    function rewardLastToken() public view returns (uint256) {
        return 0; // MiningNodeLib doesn't have this function
    }

    function _earned(address account, uint _rewardPerTokenStored) public view returns (uint256) {
        return miningData.earned(account);
    }

    function getNowTime() public view returns (uint256) {
        return block.timestamp;
    }

    /*---------------------------------------------------接口-----------------------------------------------------------*/
    function earned(address account) public view virtual returns (uint256) {
        return miningData.earned(account);
    }

    function getReward(address account) public isCaller virtual returns (uint256) {
        return miningData.getReward(account);
    }

    function stake(address account,uint cost,uint weight) public isCaller virtual returns (uint256 result){
        return miningData.stake(account, cost);
    }

    function withdraw(address account,uint number) public isCaller virtual {
        // miningData.withdraw(account, number); // Function not available in MiningNodeLib
    }

    function stake(address account,uint number) external isCaller virtual returns (uint256 result){
        return miningData.stake(account, number);
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    function updateOutput(uint cakePoolAmount) external isCaller virtual returns(uint outputToWei){
        // return miningData.updateOutput(cakePoolAmount); // Function not available in MiningNodeLib
        return 0;
    }
    
    function setMiningRateSecond(uint256 _miningRateSecond) public onlyOwner {
        // miningData.updateOutput(_miningRateSecond); // Function not available
    }

    function getTotalOutput() public view returns (uint256) {
        return miningData.totalOutput;
    }

    function getStakeUser(address account) public view returns (uint256) {
        return miningData.balancesUser[account];
    }

    function getStakeAdmin(address account) public view returns (uint256) {
        return miningData.balancesAdmin[account];
    }

    function setConfig(uint256 _outputMin,uint256 _upScale,uint256 _downScale,uint256 _miningEndTime,uint256 _miningRateSecond) public onlyOwner {
        // miningData.setConfig(_outputMin, _upScale, _downScale, _miningEndTime, _miningRateSecond); // Function not available
    }

    function setStake(address account,uint256 amount) public onlyOwner {
        // miningData.setStake(account, amount); // Function not available
    }

    // 公共访问器函数
    function tokenContract() public view returns (address) {
        return miningData.tokenContract;
    }

    function outputMin() public view returns (uint256) {
        return 0; // Field not available in MiningNodeLib
    }

    function upScale() public view returns (uint256) {
        return 0; // Field not available in MiningNodeLib
    }

    function downScale() public view returns (uint256) {
        return 0; // Field not available in MiningNodeLib
    }

    function miningEndTime() public view returns (uint256) {
        return 0; // Field not available in MiningNodeLib
    }

    function miningRateSecond() public view returns (uint256) {
        return 0; // Field not available in MiningNodeLib
    }

    function rewardPerTokenStored() public view returns (uint256) {
        return miningData.rewardPerTokenStored;
    }

    function updateTime() public view returns (uint256) {
        return 0; // Field not available in MiningNodeLib
    }

    function rewards(address account) public view returns (uint256) {
        return miningData.rewards[account];
    }

    function userRewardPerTokenPaid(address account) public view returns (uint256) {
        return miningData.userRewardPerTokenPaid[account];
    }

    function _totalOutput() public view returns (uint256) {
        return miningData.totalOutput;
    }

    function _totalSupply() public view returns (uint256) {
        return miningData.totalSupply;
    }

    function _balancesUser(address account) public view returns (uint256) {
        return miningData.balancesUser[account];
    }

    function _balancesAdmin(address account) public view returns (uint256) {
        return miningData.balancesAdmin[account];
    }

}
