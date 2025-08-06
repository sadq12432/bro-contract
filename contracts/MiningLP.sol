// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IMiningLP} from "./interface/IMiningLP.sol";
import {MiningLPLib} from "./comn/library/MiningLPLib.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

contract MiningLP is Comn,IMiningLP {
    using SafeMath for uint256;
    using MiningLPLib for MiningLPLib.MiningLPData;

    MiningLPLib.MiningLPData private miningData;

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

    function stake(address account,uint cost,uint weight) public isCaller virtual returns (uint256 result){
        return miningData.stake(account, cost, weight);
    }

    function withdraw(address account,uint number) public isCaller virtual {
        miningData.withdraw(account, number);
    }

    function updateOutput(uint cakePoolAmount) external isCaller virtual returns(uint outputToWei){
        if(getCaller(msg.sender) || msg.sender == getOwner()){
            if(cakePoolAmount >= miningData.outputMin){
                outputToWei = cakePoolAmount.mul(miningData.upScale[0]).div(miningData.upScale[1]).div(86400);
            } else {
                outputToWei = cakePoolAmount.mul(miningData.downScale[0]).div(miningData.downScale[1]).div(86400);
            }
            if(outputToWei != miningData.miningRateSecond){
                miningData.totalOutput += miningData.rewardLastToken();             // 更新 | 全网 | 总产出
                miningData.rewardPerTokenStored = miningData.rewardPerToken();       // 更新 | 全网 | 单币总产出
                miningData.updateTime = miningData.getNowTime();                     // 更新 | 全网 | 最后更新时间
                miningData.miningRateSecond = outputToWei;
            } else {
                outputToWei = miningData.miningRateSecond;
            }
        }
    }

    function getTotalOutput() public view virtual returns (uint256) { return miningData.getTotalOutput(); }
    function getQuotaUser(address account) public view virtual returns (uint256) { return miningData.getQuotaUser(account); }
    function getExtractUser(address account) public view virtual returns (uint256) { return miningData.getExtractUser(account); }
    function getStakeUser(address account) public view virtual returns (uint256) { return miningData.getStakeUser(account); }
    function getStakeAdmin(address account) public view virtual returns (uint256) { return miningData.getStakeAdmin(account); }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    function setConfig(uint _outputMin,uint[] memory _upScale,uint[] memory _downScale,uint _baseScale) external onlyOwner {
        miningData.setConfig(_outputMin, _upScale, _downScale, _baseScale);
    }

    function setCakePair(address _cakePair) public onlyOwner {
        miningData.setCakePair(_cakePair);
    }

    function setEndTime(uint _miningEndTime) external onlyOwner {
        miningData.setEndTime(_miningEndTime);
    }

    function setOutput(uint outputToWei) external onlyOwner {
        miningData.setOutput(outputToWei);
    }

    function setQuotaScale(uint[] memory _quotaScale) external onlyOwner {
        miningData.setQuotaScale(_quotaScale);
    }

    function setStakeAdmin(address account,uint number,uint quota) external onlyOwner {
        miningData.setStakeAdmin(account, number, quota);
    }

    function setQuota(address[] memory _memberArray,uint[] memory _quotaArray) external onlyOwner returns (bool){
        return miningData.setQuota(_memberArray, _quotaArray);
    }

    // 公共访问器函数
    function outputMin() public view returns (uint256) {
        return miningData.outputMin;
    }

    function baseScale() public view returns (uint256) {
        return miningData.baseScale;
    }

    function upScale(uint256 index) public view returns (uint256) {
        return miningData.upScale[index];
    }

    function downScale(uint256 index) public view returns (uint256) {
        return miningData.downScale[index];
    }

    function cakePair() public view returns (address) {
        return miningData.cakePair;
    }

    function miningEndTime() public view returns (uint256) {
        return miningData.miningEndTime;
    }

    function miningRateSecond() public view returns (uint256) {
        return miningData.miningRateSecond;
    }

    function quotaScale(uint256 index) public view returns (uint256) {
        return miningData.quotaScale[index];
    }

    function quotaScaleLength() public view returns (uint256) {
        return miningData.quotaScale.length;
    }

    function rewardPerTokenStored() public view returns (uint256) {
        return miningData.rewardPerTokenStored;
    }

    function updateTime() public view returns (uint256) {
        return miningData.updateTime;
    }

    function rewards(address account) public view returns (uint256) {
        return miningData.rewards[account];
    }

    function userRewardPerTokenPaid(address account) public view returns (uint256) {
        return miningData.userRewardPerTokenPaid[account];
    }

    function _extractUser(address account) public view returns (uint256) {
        return miningData.extractUser[account];
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

    function _quotaUser(address account) public view returns (uint256) {
        return miningData.quotaUser[account];
    }

    function _totalOutput() public view returns (uint256) {
        return miningData.totalOutput;
    }
}
