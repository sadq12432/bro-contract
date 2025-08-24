// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";

library MiningLPLib {
    using SafeMath for uint256;
    
    event LPStakeEvent(address indexed account, uint256 amount, uint256 totalSupply, uint256 userBalance, uint256 lastClaimTime);

    struct MiningLPData {
        uint256 totalSupply;
        mapping(address => uint256) balancesUser;
        mapping(address => uint256) lastClaimTime;
        mapping(address => uint256) claimedRewards;
        mapping(address => uint256) stakingLimit;
        uint256 totalPerformance;
        uint256 stakingThreshold;
        uint256 dailyRate;
        uint256 lastBurnClaimTime;
        uint256 dailyBurnRate;
    }

    function stake(MiningLPData storage data, address account, uint256 amount) internal {
        if (data.balancesUser[account] == 0) {
            data.lastClaimTime[account] = block.timestamp;
        }
        
        data.totalSupply = data.totalSupply.add(amount);
        data.balancesUser[account] = data.balancesUser[account].add(amount);
        
        updateUserStakingLimit(data, account);
        
        emit LPStakeEvent(account, amount, data.totalSupply, data.balancesUser[account], data.lastClaimTime[account]);
    }

    function earned(MiningLPData storage data, address account) internal view returns (uint256) {
        if (data.balancesUser[account] == 0 || data.totalSupply == 0 || data.lastClaimTime[account] == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp.sub(data.lastClaimTime[account]);
        uint256 dailyReward = data.totalSupply.mul(data.dailyRate).div(1000);
        
        uint256 reward = dailyReward.mul( data.balancesUser[account]).mul(timeElapsed).div(data.totalSupply).div(86400);
        
        uint256 maxReward = data.stakingLimit[account];
        if (maxReward == 0) {
            maxReward = data.balancesUser[account];
        }
        
        uint256 totalPotentialReward = data.claimedRewards[account].add(reward);
        
        if (totalPotentialReward > maxReward) {
            if (data.claimedRewards[account] >= maxReward) {
                return 0;
            }
            reward = maxReward.sub(data.claimedRewards[account]);
        }
        if(reward<0) return 0;
        
        return reward;
    }

    function getReward(MiningLPData storage data, address account) internal returns (uint256) {
        uint256 reward = earned(data, account);
        
        if (reward > 0) {
            data.lastClaimTime[account] = block.timestamp;
            data.claimedRewards[account] = data.claimedRewards[account].add(reward);
        }
        
        return reward;
    }

    function calculateDailyBurnAmount(MiningLPData storage data) internal view returns (uint256) {
        if (data.totalSupply == 0) {
            return 0;
        }
        return data.totalSupply.mul(data.dailyBurnRate).div(1000);
    }

    function getBurnMiningAmount(MiningLPData storage data, uint256 timeElapsed) internal view returns (uint256) {
        if (data.totalSupply == 0 || timeElapsed == 0) {
            return 0;
        }
        uint256 dailyBurnAmount = calculateDailyBurnAmount(data);
        return dailyBurnAmount.mul(timeElapsed).div(86400);
    }

    function calculateBurnAmount(MiningLPData storage data) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp.sub(data.lastBurnClaimTime);
        uint256 burnAmount = getBurnMiningAmount(data, timeElapsed);
        return burnAmount;
    }

    function claimBurnMining(MiningLPData storage data) internal returns (uint256) {
        if (data.lastBurnClaimTime == 0) {
            data.lastBurnClaimTime = block.timestamp;
            return 0;
        }
        
        uint256 burnAmount = calculateBurnAmount(data);
        
        data.lastBurnClaimTime = block.timestamp;
        if(burnAmount<0) return 0;
        return burnAmount;
    }

    function initialize(MiningLPData storage data) internal {
        data.dailyRate = 8;
        data.dailyBurnRate = 12;
        data.stakingThreshold = 100 ether;
    }

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
    
    function updateUserStakingLimit(MiningLPData storage data, address account) internal {
        uint256 userBalance = data.balancesUser[account];
        uint256 newLimit;
        
        if (data.totalPerformance < data.stakingThreshold) {
            newLimit = userBalance;
        } else {
            newLimit = userBalance.mul(2);
        }
        
        data.stakingLimit[account] = newLimit;
    }
    
    function updateStakingLimit(MiningLPData storage data, address account, uint256 newLimit) internal {
        data.stakingLimit[account] = newLimit;
    }
    
    function getStakingLimit(MiningLPData storage data, address account) internal view returns (uint256) {
        return data.stakingLimit[account];
    }
    
    function setStakingThreshold(MiningLPData storage data, uint256 newThreshold) internal {
        require(newThreshold > 0, "Staking threshold must be greater than 0");
        data.stakingThreshold = newThreshold;
    }
    
    function getStakingThreshold(MiningLPData storage data) internal view returns (uint256) {
        return data.stakingThreshold;
    }
    
    function getTotalPerformance(MiningLPData storage data) internal view returns (uint256) {
        return data.totalPerformance;
    }
}