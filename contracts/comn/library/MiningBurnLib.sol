// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {SafeMath} from "./SafeMath.sol";
import {AbsERC20} from "../abstract/AbsERC20.sol";

library MiningBurnLib {
    using SafeMath for uint256;

    struct MiningData {
        uint256 rewardPerTokenStored;                        // 每单位 token 奖励数量, 此值放大了1e18倍
        mapping(address => uint256) userRewardPerTokenPaid;  // 已采集量, 此值放大了1e18倍
        mapping(address => uint256) rewards;                 // 余额
        uint256 totalOutput;                                 // 全网总产出量
        uint256 totalSupply;                                 // 全网总质押算力
        mapping(address => uint256) balancesUser;            // 地址总质押算力
        mapping(address => uint256) balancesAdmin;           // 系统总质押算力
        address tokenContract;                               // 代币合约地址
        uint256 outputMin;                                   // 最小产出量
        uint[] upScale;                                      // 上升比例
        uint[] downScale;                                    // 下降比例
        uint256 baseScale;                                   // 基础比例
    }

    // 更新挖矿奖励
    function updateReward(MiningData storage data, address account) internal {
        if (account != address(0)) {
            data.rewards[account] = earned(data, account);                        // 更新 | 个人 | 收益余额
            data.userRewardPerTokenPaid[account] = data.rewardPerTokenStored;    // 更新 | 个人 | 收益时刻
        }
    }

    function earned(MiningData storage data, address account) internal view returns (uint256) {
        return data.rewards[account] + (data.balancesUser[account] + data.balancesAdmin[account]) * (data.rewardPerTokenStored - data.userRewardPerTokenPaid[account]) / 1e18;
    }

    function getReward(MiningData storage data, address account) internal returns (uint256) {
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

    function stake(MiningData storage data, address account, uint number) internal returns (uint256 result){
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

    function updateOutput(MiningData storage data, uint amountIn) internal returns(uint outputToWei){
        if (data.totalSupply > 0) { 
            data.rewardPerTokenStored += (amountIn * 1e18 / data.totalSupply); 
        }
        data.totalOutput += amountIn;
        outputToWei = data.totalOutput;
    }

    function setConfig(MiningData storage data, address _tokenContract) internal {
        data.tokenContract = _tokenContract;
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