// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";

library MiningNodeLib {
    using SafeMath for uint256;

    struct MiningNodeData {
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
    }

    struct TeamRewardData {
        mapping(address => uint256) unclaimedRewards;
    }

    struct TeamPerformanceData {
        uint256 totalTeamPerformance;
        mapping(address => uint256) teamPerformance;
        mapping(address => uint256) personalPerformance;
        mapping(address => bool) nodePool;
        address[] nodePoolAddresses;
        uint256 totalNodePerformance;
    }

    function addUnclaimedReward(
        TeamRewardData storage data,
        address user,
        uint256 amount
    ) internal {
        data.unclaimedRewards[user] = data.unclaimedRewards[user].add(amount);
    }

    function getUnclaimedReward(
        TeamRewardData storage data,
        address user
    ) internal view returns (uint256) {
        return data.unclaimedRewards[user];
    }

    function claimReward(
        TeamRewardData storage data,
        address user
    ) internal returns (uint256) {
        uint256 reward = data.unclaimedRewards[user];
        data.unclaimedRewards[user] = 0;
        return reward;
    }

    function earned(MiningNodeData storage data, address account) internal view returns (uint256) {
        return data.rewards[account];
    }

    function getReward(MiningNodeData storage data, address account) internal returns (uint256) {
        uint256 reward = earned(data, account);
        if (reward > 0) {
            data.rewards[account] = 0;
            return reward;
        } else {
            return 0;
        }
    }

    function addTeamPerformance(
        TeamPerformanceData storage data,
        address user,
        uint256 amount
    ) internal {
        data.teamPerformance[user] = data.teamPerformance[user].add(amount);
        data.totalTeamPerformance = data.totalTeamPerformance.add(amount);
        
        if (data.nodePool[user]) {
            data.totalNodePerformance = data.totalNodePerformance.add(amount);
        }
    }

    function getTeamPerformance(
        TeamPerformanceData storage data,
        address user
    ) internal view returns (uint256) {
        return data.teamPerformance[user];
    }

    function getTotalTeamPerformance(
        TeamPerformanceData storage data
    ) internal view returns (uint256) {
        return data.totalTeamPerformance;
    }

    function addToNodePool(
        TeamPerformanceData storage data,
        address user
    ) internal {
        if (!data.nodePool[user]) {
            data.nodePool[user] = true;
            data.nodePoolAddresses.push(user);
            
            uint256 userTeamPerformance = data.teamPerformance[user];
            data.totalNodePerformance = data.totalNodePerformance.add(userTeamPerformance);
        }
    }

    function removeFromNodePool(
        TeamPerformanceData storage data,
        address user
    ) internal {
        if (data.nodePool[user]) {
            data.nodePool[user] = false;
            
            for (uint256 i = 0; i < data.nodePoolAddresses.length; i++) {
                if (data.nodePoolAddresses[i] == user) {
                    data.nodePoolAddresses[i] = data.nodePoolAddresses[data.nodePoolAddresses.length - 1];
                    data.nodePoolAddresses.pop();
                    break;
                }
            }
        }
    }

    function isInNodePool(
        TeamPerformanceData storage data,
        address user
    ) internal view returns (bool) {
        return data.nodePool[user];
    }

    function getNodePoolAddresses(
        TeamPerformanceData storage data
    ) internal view returns (address[] memory) {
        return data.nodePoolAddresses;
    }

    function getNodePoolSize(
        TeamPerformanceData storage data
    ) internal view returns (uint256) {
        return data.nodePoolAddresses.length;
    }

    function updatePersonalPerformance(
        TeamPerformanceData storage data,
        address user,
        uint256 newAmount
    ) internal {
        data.personalPerformance[user] = newAmount;
    }

    function getPersonalPerformance(
        TeamPerformanceData storage data,
        address user
    ) internal view returns (uint256) {
        return data.personalPerformance[user];
    }

    function getTotalNodePerformance(
        TeamPerformanceData storage data
    ) internal view returns (uint256) {
        return data.totalNodePerformance;
    }

    function addPersonalPerformance(
        TeamPerformanceData storage data,
        address user,
        uint256 amount
    ) internal {
        data.personalPerformance[user] = data.personalPerformance[user].add(amount);
    }
    
    function setTeamAmount(
        TeamPerformanceData storage data,
        address user,
        uint256 amount
    ) internal {
        uint256 oldAmount = data.teamPerformance[user];
        data.teamPerformance[user] = amount;
        
        if (amount > oldAmount) {
            data.totalTeamPerformance = data.totalTeamPerformance.add(amount.sub(oldAmount));
        } else if (amount < oldAmount) {
            data.totalTeamPerformance = data.totalTeamPerformance.sub(oldAmount.sub(amount));
        }
    }
    
    function setPersonalAmount(
        TeamPerformanceData storage data,
        address user,
        uint256 amount
    ) internal {
        data.personalPerformance[user] = amount;
    }

    function distributeNodePoolRewards(
        MiningNodeData storage miningData,
        TeamPerformanceData storage teamData,
        uint256 totalReward
    ) internal {
        require(totalReward > 0, "Total reward must be greater than 0");
        address[] memory nodeAddresses = getNodePoolAddresses(teamData);
        if (nodeAddresses.length == 0) {
            return;
        }
        
        uint256 totalTeamAmount = getTotalNodePerformance(teamData);
        
        if(totalTeamAmount == 0){
            return;
        }
        
        for (uint256 i = 0; i < nodeAddresses.length; i++) {
           uint256  teamAmounts = getTeamPerformance(teamData, nodeAddresses[i]);
            if (teamAmounts > 0) {
                uint256 reward = (totalReward.mul(teamAmounts))/ totalTeamAmount;
                address nodeAddr = nodeAddresses[i];
                miningData.rewards[nodeAddr] += reward;
            }
        }
    }

    function checkAndAddToNodePool(
        TeamPerformanceData storage teamData,
        address user,
        uint256 nodeThreshold,
        uint256 personalThreshold
    ) internal returns (bool) {
        if (teamData.teamPerformance[user] >= nodeThreshold && 
            teamData.personalPerformance[user] >= personalThreshold && 
            !teamData.nodePool[user]) {
            addToNodePool(teamData, user);
            return true;
        }
        return false;
    }
    
    function updateTeamAmountWithTokenLP(
        TeamPerformanceData storage teamData,
        address user,
        uint256 amount,
        mapping(address => address) storage inviterMap,
        uint256 nodeThreshold,
        uint256 personalThreshold,
        uint256 totalPerformanceRef
    ) internal returns (uint256 newTotalPerformance, address[] memory newNodeUsers) {
        newTotalPerformance = totalPerformanceRef + amount;
        
        address currentUser = user;
        address[] memory tempNewUsers = new address[](3);
        uint256 newUserCount = 0;
        
        for (uint i = 0; i < 3 && currentUser != address(0); i++) {
            addTeamPerformance(teamData, currentUser, amount);
            
            if (i == 0) {
                addPersonalPerformance(teamData, currentUser, amount);
            }
            
            if (checkAndAddToNodePool(teamData, currentUser, nodeThreshold, personalThreshold)) {
                tempNewUsers[newUserCount] = currentUser;
                newUserCount++;
            }
            
            currentUser = inviterMap[currentUser];
        }
        
        newNodeUsers = new address[](newUserCount);
        for (uint i = 0; i < newUserCount; i++) {
            newNodeUsers[i] = tempNewUsers[i];
        }
        
        return (newTotalPerformance, newNodeUsers);
    }
}