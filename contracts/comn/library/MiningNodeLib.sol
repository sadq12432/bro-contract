// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";
import {AbsERC20} from "../abstract/AbsERC20.sol";

library MiningNodeLib {
    using SafeMath for uint256;

    struct MiningNodeData {
        uint256 rewardPerTokenStored;                        // 每单位 token 奖励数量, 此值放大了1e18倍
        mapping(address => uint256) userRewardPerTokenPaid;  // 已采集量, 此值放大了1e18倍
        mapping(address => uint256) rewards;                 // 余额
        uint256 totalOutput;                                 // 全网总产出量
        uint256 totalSupply;                                 // 全网总质押算力
        mapping(address => uint256) balancesUser;            // 地址总质押算力
        mapping(address => uint256) balancesAdmin;           // 系统总质押算力
        address tokenContract;                               // 代币合约地址
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

    // MiningNodeData相关函数
    // 更新挖矿奖励
    function updateReward(MiningNodeData storage data, address account) internal {
        if (account != address(0)) {
            data.rewards[account] = earned(data, account);                        // 更新 | 个人 | 收益余额
            data.userRewardPerTokenPaid[account] = data.rewardPerTokenStored;    // 更新 | 个人 | 收益时刻
        }
    }

    function earned(MiningNodeData storage data, address account) internal view returns (uint256) {
        return data.rewards[account] + (data.balancesUser[account] + data.balancesAdmin[account]) * (data.rewardPerTokenStored - data.userRewardPerTokenPaid[account]) / 1e18;
    }

    function getReward(MiningNodeData storage data, address account) internal returns (uint256) {
        updateReward(data, account);
        uint256 reward = earned(data, account);
        if (reward > 0) {
            data.rewards[account] = 0;
            AbsERC20(data.tokenContract).transfer(account, reward);
            return reward;
        } else {
            return 0;
        }
    }

    function stake(MiningNodeData storage data, address account, uint number) internal returns (uint256 result){
        updateReward(data, account);
        data.totalSupply += number;
        data.balancesUser[account] += number;
        return number;
    }

    function withdraw(MiningNodeData storage data, address account, uint number) internal {
        updateReward(data, account);
        if(data.balancesUser[account] >= number){
            data.totalSupply -= number;
            data.balancesUser[account] -= number;
        }
    }

    function updateOutput(MiningNodeData storage data, uint amountIn) internal returns(uint outputToWei){
        if (data.totalSupply > 0) { 
            data.rewardPerTokenStored += (amountIn * 1e18 / data.totalSupply); 
        }
        data.totalOutput += amountIn;
        outputToWei = data.totalOutput;
    }

    function setConfig(MiningNodeData storage data, address _tokenContract) internal {
        data.tokenContract = _tokenContract;
    }

    function setStake(MiningNodeData storage data, address account, uint number) internal {
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
    function getTotalOutput(MiningNodeData storage data) internal view returns (uint256) { return data.totalOutput; }
    function getStakeUser(MiningNodeData storage data, address account) internal view returns (uint256) { return data.balancesUser[account]; }
    function getStakeAdmin(MiningNodeData storage data, address account) internal view returns (uint256) { return data.balancesAdmin[account]; }
}