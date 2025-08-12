// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";

library MiningLPLib {
    using SafeMath for uint256;

    struct MiningLPData {
        uint256 totalSupply;                                 // 全网总质押量
        mapping(address => uint256) balancesUser;            // 用户质押量
        mapping(address => uint256) lastClaimTime;           // 用户上次领取时间
        mapping(address => uint256) claimedRewards;          // 用户已领取的收益总额
        uint256 dailyRate;                                   // 每日产出率 (0.8% = 8/1000)
        uint256 lastBurnClaimTime;                           // 上次领取燃烧挖矿时间（全局）
        uint256 dailyBurnRate;                               // 每日燃烧率 (1.2% = 12/1000)
    }

    // 用户质押
    function stake(MiningLPData storage data, address account, uint256 amount) internal {
        // 如果是首次质押，设置领取时间为当前时间
        if (data.balancesUser[account] == 0) {
            data.lastClaimTime[account] = block.timestamp;
        }
        
        data.totalSupply = data.totalSupply.add(amount);
        data.balancesUser[account] = data.balancesUser[account].add(amount);
    }

    // 计算用户未领取的收益
    function earned(MiningLPData storage data, address account) internal view returns (uint256) {
        if (data.balancesUser[account] == 0 || data.totalSupply == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp.sub(data.lastClaimTime[account]);
        uint256 dailyReward = data.totalSupply.mul(data.dailyRate).div(1000); // 总质押量的0.8%
        
        // 计算用户在这段时间内的收益
        uint256 reward = dailyReward.mul( data.balancesUser[account]).mul(timeElapsed).div(data.totalSupply).div(86400); // 86400秒 = 1天
        
        // 检查收益上限：已领取收益 + 当前收益不能超过质押量
        uint256 maxReward = data.balancesUser[account];
        uint256 totalPotentialReward = data.claimedRewards[account].add(reward);
        
        if (totalPotentialReward > maxReward) {
            // 如果超过上限，只返回剩余可领取的部分
            if (data.claimedRewards[account] >= maxReward) {
                return 0; // 已经达到上限
            }
            reward = maxReward.sub(data.claimedRewards[account]);
        }
        if(reward<0) return 0;
        
        return reward;
    }

    // 领取收益
    function getReward(MiningLPData storage data, address account) internal returns (uint256) {
        uint256 reward = earned(data, account);
        
        if (reward > 0) {
            data.lastClaimTime[account] = block.timestamp;
            data.claimedRewards[account] = data.claimedRewards[account].add(reward);
        }
        
        return reward;
    }

    // 计算每日燃烧量（基于总质押量的1.2%）
    function calculateDailyBurnAmount(MiningLPData storage data) internal view returns (uint256) {
        if (data.totalSupply == 0) {
            return 0;
        }
        return data.totalSupply.mul(data.dailyBurnRate).div(1000); // 总质押量的1.2%
    }

    // 按时间差获取燃烧挖矿量
    function getBurnMiningAmount(MiningLPData storage data, uint256 timeElapsed) internal view returns (uint256) {
        if (data.totalSupply == 0 || timeElapsed == 0) {
            return 0;
        }
        uint256 dailyBurnAmount = calculateDailyBurnAmount(data);
        return dailyBurnAmount.mul(timeElapsed).div(86400); // 86400秒 = 1天
    }

    // 领取燃烧挖矿（按时间差计算并更新领取时间）
    function claimBurnMining(MiningLPData storage data) internal returns (uint256) {
        // 如果是首次领取，设置领取时间为当前时间
        if (data.lastBurnClaimTime == 0) {
            data.lastBurnClaimTime = block.timestamp;
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp.sub(data.lastBurnClaimTime);
        uint256 burnAmount = getBurnMiningAmount(data, timeElapsed);
        
        // 更新领取时间为当前时间
        data.lastBurnClaimTime = block.timestamp;
        if(burnAmount<0) return 0;
        return burnAmount;
    }

    // 初始化配置
    function initialize(MiningLPData storage data) internal {
        data.dailyRate = 8; // 0.8%
        data.dailyBurnRate = 12; // 1.2%
    }

    // Getter functions
    function getTotalSupply(MiningLPData storage data) internal view returns (uint256) {
        return data.totalSupply;
    }
    
    function getUserBalance(MiningLPData storage data, address account) internal view returns (uint256) {
        return data.balancesUser[account];
    }
    
    function getLastClaimTime(MiningLPData storage data, address account) internal view returns (uint256) {
        return data.lastClaimTime[account];
    }
    
    function getClaimedRewards(MiningLPData storage data, address account) internal view returns (uint256) {
        return data.claimedRewards[account];
    }
    
    function getRemainingRewards(MiningLPData storage data, address account) internal view returns (uint256) {
        if (data.balancesUser[account] == 0) {
            return 0;
        }
        uint256 maxReward = data.balancesUser[account];
        uint256 claimed = data.claimedRewards[account];
        return claimed >= maxReward ? 0 : maxReward.sub(claimed);
    }
    
    function getLastBurnClaimTime(MiningLPData storage data) internal view returns (uint256) {
        return data.lastBurnClaimTime;
    }
    
    function getDailyBurnRate(MiningLPData storage data) internal view returns (uint256) {
        return data.dailyBurnRate;
    }
    
    function getPendingBurnAmount(MiningLPData storage data) internal view returns (uint256) {
        if (data.lastBurnClaimTime == 0) {
            return 0;
        }
        uint256 timeElapsed = block.timestamp.sub(data.lastBurnClaimTime);
        return getBurnMiningAmount(data, timeElapsed);
    }
}