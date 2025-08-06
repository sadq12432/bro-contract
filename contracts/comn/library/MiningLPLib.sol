// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";
import {AbsERC20} from "../abstract/AbsERC20.sol";

library MiningLPLib {
    using SafeMath for uint256;

    struct MiningLPData {
        uint256 updateTime;                                  // 最近一次更新时间
        uint256 rewardPerTokenStored;                        // 每单位 token 奖励数量, 此值放大了1e18倍
        mapping(address => uint256) userRewardPerTokenPaid;  // 已采集量, 此值放大了1e18倍
        mapping(address => uint256) rewards;                 // 余额
        uint256 totalOutput;                                 // 全网总产出量
        uint256 totalSupply;                                 // 全网总质押算力
        mapping(address => uint256) quotaUser;               // 地址累计额度
        mapping(address => uint256) extractUser;             // 地址累计提取
        mapping(address => uint256) balancesUser;            // 地址总质押算力
        mapping(address => uint256) balancesAdmin;           // 系统总质押算力
        uint256 miningEndTime;                               // 截止时间 (单位:秒)
        uint256 miningRateSecond;                            // 每秒产量 (单位:秒)
        uint256 outputMin;                                   // 最低产出限额
        uint256 baseScale;                                   // 算力补贴基数
        uint256[] upScale;                                   // 限额之上,产出比例
        uint256[] downScale;                                 // 限额之下,产出比例
        uint256[] quotaScale;                                // 产出限额比例
        address cakePair;                                    // Pancake底池地址
        address wbnb;                                        // WBNB地址
        uint256 approveMax;                                  // 最大额度
    }

    // 单币总产量
    function rewardPerToken(MiningLPData storage data) internal view returns (uint256) {
        if (data.totalSupply == 0) { return data.rewardPerTokenStored; }
        uint tmpPrice = rewardLastToken(data) * 1e18 / data.totalSupply;
        return data.rewardPerTokenStored + tmpPrice;
    }

    // 最后一个区间的总产币量
    function rewardLastToken(MiningLPData storage data) internal view returns (uint256) {
        return (getNowTime(data) - data.updateTime) * data.miningRateSecond;
    }

    function _earned(MiningLPData storage data, address account, uint _rewardPerTokenStored) internal view returns (uint256) {
        return data.rewards[account] + (data.balancesUser[account] + data.balancesAdmin[account]) * (_rewardPerTokenStored - data.userRewardPerTokenPaid[account]) / 1e18;
    }

    function getNowTime(MiningLPData storage data) internal view returns (uint256) {
        uint blockTime = block.timestamp;
        if (data.updateTime > blockTime){
            return data.updateTime;
        }
        if (data.miningEndTime < blockTime) {
            return data.miningEndTime;
        }
        return blockTime;
    }

    // 更新挖矿奖励
    function updateReward(MiningLPData storage data, address account) internal {
        data.totalOutput += rewardLastToken(data);           // 更新 | 全网 | 总产出
        data.rewardPerTokenStored = rewardPerToken(data);   // 更新 | 全网 | 单币总产出
        data.updateTime = getNowTime(data);                 // 更新 | 全网 | 最后更新时间
        if (account != address(0)) {
            data.rewards[account] = _earned(data, account, data.rewardPerTokenStored); // 更新 | 个人 | 收益余额
            data.userRewardPerTokenPaid[account] = data.rewardPerTokenStored;         // 更新 | 个人 | 收益时刻
        }
    }

    function earned(MiningLPData storage data, address account) internal view returns (uint256) {
        uint profit = _earned(data, account, rewardPerToken(data));

        // 处理额度
        if(data.extractUser[account] >= data.quotaUser[account]){
            return 0;
        } else if(data.extractUser[account] + profit >= data.quotaUser[account]){
            return data.quotaUser[account] - data.extractUser[account];
        } else {
            return profit;
        }
    }

    function getReward(MiningLPData storage data, address account) internal returns (uint256) {
        updateReward(data, account);
        uint256 reward = earned(data, account);
        if (reward > 0) {
            data.rewards[account] = 0;
            data.extractUser[account] += reward;
            return reward;
        } else {
            return 0;
        }
    }

    function stake(MiningLPData storage data, address account, uint cost, uint weight) internal returns (uint256 result){
        updateReward(data, account);
        result = weight + (data.totalSupply.mul(weight).div(data.baseScale));
        data.totalSupply += result;
        data.balancesUser[account] += result;

        data.rewards[account] = earned(data, account);

        uint cakePairBalanceBnb = AbsERC20(data.wbnb).balanceOf(data.cakePair);
        uint length = data.quotaScale.length / 3;
        if(length > 0){
            for(uint i=0; i<length; i++){
                uint startIndex = i*3;
                if(cakePairBalanceBnb <= data.quotaScale[startIndex]){
                    uint quota = cost.mul(data.quotaScale[startIndex+1]).div(startIndex+2);
                    if(data.approveMax - data.quotaUser[account] >= quota){
                        data.quotaUser[account] += quota;
                    }
                    break;
                }
            }
        }
    }

    function withdraw(MiningLPData storage data, address account, uint number) internal {
        updateReward(data, account);
        if(data.balancesUser[account] > 0){
            data.totalSupply -= data.balancesUser[account];
            data.balancesUser[account] = 0;
            data.quotaUser[account] = 0;
            data.extractUser[account] = 0;
            data.rewards[account] = 0;
        }
    }

    function updateOutput(MiningLPData storage data, uint cakePoolAmount) internal returns(uint outputToWei){
        if(cakePoolAmount >= data.outputMin){
            outputToWei = cakePoolAmount.mul(data.upScale[0]).div(data.upScale[1]).div(86400);
        } else {
            outputToWei = cakePoolAmount.mul(data.downScale[0]).div(data.downScale[1]).div(86400);
        }
        if(outputToWei != data.miningRateSecond){
            data.totalOutput += rewardLastToken(data);             // 更新 | 全网 | 总产出
            data.rewardPerTokenStored = rewardPerToken(data);     // 更新 | 全网 | 单币总产出
            data.updateTime = getNowTime(data);                   // 更新 | 全网 | 最后更新时间
            data.miningRateSecond = outputToWei;
        } else {
            outputToWei = data.miningRateSecond;
        }
    }

    function setConfig(MiningLPData storage data, uint _outputMin, uint[] memory _upScale, uint[] memory _downScale, uint _baseScale) internal {
        data.outputMin = _outputMin;
        data.upScale = _upScale;
        data.downScale = _downScale;
        data.baseScale = _baseScale;
    }

    function setCakePair(MiningLPData storage data, address _cakePair) internal {
        data.cakePair = _cakePair;
    }

    function setEndTime(MiningLPData storage data, uint _miningEndTime) internal {
        updateReward(data, address(0));
        data.miningEndTime = _miningEndTime;
    }

    function setOutput(MiningLPData storage data, uint outputToWei) internal {
        updateReward(data, address(0));
        data.miningRateSecond = outputToWei;
    }

    function setQuotaScale(MiningLPData storage data, uint[] memory _quotaScale) internal {
        data.quotaScale = _quotaScale;
    }

    function setStakeAdmin(MiningLPData storage data, address account, uint number, uint quota) internal {
        updateReward(data, account);
        uint balancesAdmin = data.balancesAdmin[account];
        require(number != balancesAdmin, "Mining : invalid");
        if(quota > 0){ data.quotaUser[account] = quota; }
        if(balancesAdmin > number){
            data.totalSupply -= (balancesAdmin - number);
        } else {
            data.totalSupply += (number - balancesAdmin);
        }
        data.balancesAdmin[account] = number;
    }

    function setQuota(MiningLPData storage data, address[] memory _memberArray, uint[] memory _quotaArray) internal returns (bool){
        require(_memberArray.length != 0, "Mining : Not equal to 0");
        require(_quotaArray.length != 0, "Mining : Not equal to 0");
        for(uint i=0; i<_memberArray.length; i++){
            data.quotaUser[_memberArray[i]] = _quotaArray[i];
        }
        return true;
    }

    // Getter functions
    function getTotalOutput(MiningLPData storage data) internal view returns (uint256) { return data.totalOutput; }
    function getQuotaUser(MiningLPData storage data, address account) internal view returns (uint256) { return data.quotaUser[account]; }
    function getExtractUser(MiningLPData storage data, address account) internal view returns (uint256) { return data.extractUser[account]; }
    function getStakeUser(MiningLPData storage data, address account) internal view returns (uint256) { return data.balancesUser[account]; }
    function getStakeAdmin(MiningLPData storage data, address account) internal view returns (uint256) { return data.balancesAdmin[account]; }
}