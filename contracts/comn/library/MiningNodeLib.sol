// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";

library MiningNodeLib {
    using SafeMath for uint256;

    struct MiningNodeData {
        uint256 rewardPerTokenStored;                        // 每单位 token 奖励数量, 此值放大了1e18倍
        mapping(address => uint256) userRewardPerTokenPaid;  // 已采集量, 此值放大了1e18倍
        mapping(address => uint256) rewards;                 // 余额
    }

    // 团队未领取奖励数据结构
    struct TeamRewardData {
        mapping(address => uint256) unclaimedRewards; // 每个地址的未领取奖励
    }

    /**
     * @dev 增加某个地址的未领取奖励量
     * @param data 团队奖励数据
     * @param user 用户地址
     * @param amount 增加的奖励数量
     */
    function addUnclaimedReward(
        TeamRewardData storage data,
        address user,
        uint256 amount
    ) internal {
        data.unclaimedRewards[user] = data.unclaimedRewards[user].add(amount);
    }

    /**
     * @dev 获取某个地址的未领取奖励量
     * @param data 团队奖励数据
     * @param user 用户地址
     * @return 未领取的奖励数量
     */
    function getUnclaimedReward(
        TeamRewardData storage data,
        address user
    ) internal view returns (uint256) {
        return data.unclaimedRewards[user];
    }

    /**
     * @dev 领取收益，并将未领取量置为0
     * @param data 团队奖励数据
     * @param user 用户地址
     * @return 领取的奖励数量
     */
    function claimReward(
        TeamRewardData storage data,
        address user
    ) internal returns (uint256) {
        uint256 reward = data.unclaimedRewards[user];
        data.unclaimedRewards[user] = 0;
        return reward;
    }

    // MiningNodeData相关的必要函数（保持与Master.sol兼容）
    function updateReward(MiningNodeData storage data, address account) internal {
        if (account != address(0)) {
            data.rewards[account] = earned(data, account);
            data.userRewardPerTokenPaid[account] = data.rewardPerTokenStored;
        }
    }

    function earned(MiningNodeData storage data, address account) internal view returns (uint256) {
        return data.rewards[account];
    }

    function getReward(MiningNodeData storage data, address account) internal returns (uint256) {
        updateReward(data, account);
        uint256 reward = earned(data, account);
        if (reward > 0) {
            data.rewards[account] = 0;
            return reward;
        } else {
            return 0;
        }
    }

    /**
     * @dev 按团队业绩加权分配奖励给节点池中的地址
     * @param data 挖矿节点数据
     * @param totalReward 总奖励金额
     * @param nodeAddresses 节点池地址数组
     * @param teamAmounts 每个地址对应的团队业绩数组
     */
    function distributeRewardsByTeamPerformance(
        MiningNodeData storage data,
        uint256 totalReward,
        address[] memory nodeAddresses,
        uint256[] memory teamAmounts
    ) internal {
        require(nodeAddresses.length == teamAmounts.length, "Arrays length mismatch");
        require(nodeAddresses.length > 0, "No node addresses provided");
        
        // 计算总团队业绩
        uint256 totalTeamAmount = 0;
        for (uint256 i = 0; i < teamAmounts.length; i++) {
            totalTeamAmount = totalTeamAmount.add(teamAmounts[i]);
        }
        
        require(totalTeamAmount > 0, "Total team amount must be greater than 0");
        
        // 按比例分配奖励
        for (uint256 i = 0; i < nodeAddresses.length; i++) {
            if (teamAmounts[i] > 0) {
                uint256 reward = totalReward.mul(teamAmounts[i]).div(totalTeamAmount);
                data.rewards[nodeAddresses[i]] = data.rewards[nodeAddresses[i]].add(reward);
            }
        }
    }
}