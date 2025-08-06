// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";

library MiningBurnLib {
    using SafeMath for uint256;

    struct MiningData {
        uint256 updateTime;                                  // 最近一次更新时间
        uint256 rewardPerTokenStored;                        // 每单位 token 奖励数量, 此值放大了1e18倍
        mapping(address => uint256) userRewardPerTokenPaid;  // 已采集量, 此值放大了1e18倍
        mapping(address => uint256) rewards;                 // 余额
        uint256 totalOutput;                                 // 全网总产出量
        uint256 totalSupply;                                 // 全网总质押算力
        mapping(address => uint256) balancesUser;            // 地址总质押算力
        mapping(address => uint256) balancesAdmin;           // 系统总质押算力
        uint256 miningEndTime;                               // 截止时间 (单位:秒)
        uint256 miningRateSecond;                            // 每秒产量 (单位:秒)
        uint256 outputMin;                                   // 最低产出限额
        uint256[] upScale;                                   // 限额之上,产出比例
        uint256[] downScale;                                 // 限额之下,产出比例
    }

    // 单币总产量
    function rewardPerToken(MiningData storage data) internal view returns (uint256) {
        if (data.totalSupply == 0) { return data.rewardPerTokenStored; }
        uint tmpPrice = rewardLastToken(data) * 1e18 / data.totalSupply;
        return data.rewardPerTokenStored + tmpPrice;
    }

    // 最后一个区间的总产币量
    function rewardLastToken(MiningData storage data) internal view returns (uint256) {
        return (getNowTime(data) - data.updateTime) * data.miningRateSecond;
    }

    function _earned(MiningData storage data, address account, uint _rewardPerTokenStored) internal view returns (uint256) {
        return data.rewards[account] + (data.balancesUser[account] + data.balancesAdmin[account]) * (_rewardPerTokenStored - data.userRewardPerTokenPaid[account]) / 1e18;
    }

    function getNowTime(MiningData storage data) internal view returns (uint256) {
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
    function updateReward(MiningData storage data, address account) internal {
        data.totalOutput += rewardLastToken(data);           // 更新 | 全网 | 总产出
        data.rewardPerTokenStored = rewardPerToken(data);   // 更新 | 全网 | 单币总产出
        data.updateTime = getNowTime(data);                 // 更新 | 全网 | 最后更新时间
        if (account != address(0)) {
            data.rewards[account] = _earned(data, account, data.rewardPerTokenStored); // 更新 | 个人 | 收益余额
            data.userRewardPerTokenPaid[account] = data.rewardPerTokenStored;         // 更新 | 个人 | 收益时刻
        }
    }

    function earned(MiningData storage data, address account) internal view returns (uint256) {
        return _earned(data, account, rewardPerToken(data));
    }

    function getReward(MiningData storage data, address account) internal returns (uint256) {
        updateReward(data, account);
        uint256 reward = earned(data, account);
        if (reward > 0) {
            data.rewards[account] = 0;
            return reward;
        } else {
            return 0;
        }
    }

    function stake(MiningData storage data, address account, uint number) internal returns (uint256) {
        updateReward(data, account);
        data.totalSupply += number;
        data.balancesUser[account] += number;
        return number;
    }

    function withdraw(MiningData storage data, address account, uint number) internal {
        updateReward(data, account);
        if(data.balancesUser[account] >= number){
            data.totalSupply -= number;
            data.balancesUser[account] -= number;
        }
    }

    function updateOutput(MiningData storage data, uint cakePoolAmount) internal returns(uint outputToWei){
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

    function setConfig(MiningData storage data, uint _outputMin, uint[] memory _upScale, uint[] memory _downScale) internal {
        data.outputMin = _outputMin;
        data.upScale = _upScale;
        data.downScale = _downScale;
    }

    function setEndTime(MiningData storage data, uint _miningEndTime) internal {
        updateReward(data, address(0));
        data.miningEndTime = _miningEndTime;
    }

    function setOutput(MiningData storage data, uint outputToWei) internal {
        updateReward(data, address(0));
        data.miningRateSecond = outputToWei;
    }

    function setStake(MiningData storage data, address account, uint number) internal {
        updateReward(data, account);
        uint balancesAdmin = data.balancesAdmin[account];
        require(number != balancesAdmin, "Mining : invalid");
        if(balancesAdmin > number){
            data.totalSupply -= (balancesAdmin - number);
        } else {
            data.totalSupply += (number - balancesAdmin);
        }
        data.balancesAdmin[account] = number;
    }

    // Getter functions
    function getTotalOutput(MiningData storage data) internal view returns (uint256) { return data.totalOutput; }
    function getStakeUser(MiningData storage data, address account) internal view returns (uint256) { return data.balancesUser[account]; }
    function getStakeAdmin(MiningData storage data, address account) internal view returns (uint256) { return data.balancesAdmin[account]; }
}