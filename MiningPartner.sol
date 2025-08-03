// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IMining} from "./interface/IMining.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

contract MiningPartner is Comn,IMining {
    using SafeMath for uint256;

    uint256 public rewardPerTokenStored;                        //每单位 token 奖励数量, 此值放大了1e18倍
    mapping(address => uint256) public userRewardPerTokenPaid;  //已采集量, 此值放大了1e18倍
    mapping(address => uint256) public rewards;                 //余额

    uint256 public _totalOutput;                                //全网总产出量
    uint256 public _totalSupply;                                //全网总质押算力
    mapping(address => uint256) private _balancesUser;          //地址总质押算力
    mapping(address => uint256) private _balancesAdmin;         //系统总质押算力


    // 更新挖矿奖励
    modifier updateReward(address account) {
        if (account != address(0)) {
            rewards[account] = earned(account);                        // 更新 | 个人 | 收益余额
            userRewardPerTokenPaid[account] = rewardPerTokenStored;    // 更新 | 个人 | 收益时刻
        }
        _;
    }

    /*---------------------------------------------------接口-----------------------------------------------------------*/
    function earned(address account) public view virtual returns (uint256) {
        return rewards[account] + (_balancesUser[account] + _balancesAdmin[account]) * (rewardPerTokenStored - userRewardPerTokenPaid[account]) / 1e18;
    }

    function getReward(address account) public updateReward(account) virtual returns (uint256) {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            AbsERC20(tokenContract).transfer(account,reward);
            return reward;
        } else {
            return 0;
        }
    }

    function stake(address account,uint number) public isCaller updateReward(account) virtual returns (uint256 result){
        _totalSupply += number;
        _balancesUser[account] += number;
    }

    function withdraw(address account,uint number) public isCaller updateReward(account) virtual {
        if(_balancesUser[account] >= number){
            _totalSupply -= number;
            _balancesUser[account] -= number;
        }
    }

    function updateOutput(uint amountIn) external isCaller virtual returns(uint outputToWei){
        if (_totalSupply > 0) { rewardPerTokenStored += (amountIn * 1e18 / _totalSupply); }
        _totalOutput += amountIn;
        outputToWei = _totalOutput;
    }

    function getTotalOutput() public view virtual returns (uint256) { return _totalOutput; }
    function getStakeUser(address account) public view virtual returns (uint256) { return _balancesUser[account]; }
    function getStakeAdmin(address account) public view virtual returns (uint256) { return _balancesAdmin[account]; }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address public tokenContract;
    function setConfig(address _tokenContract) external onlyOwner { tokenContract = _tokenContract; }
    function setStake(address account,uint number) external onlyOwner updateReward(account) {
        uint balancesAdmin = _balancesAdmin[account];
        require(number != balancesAdmin,"Mining : invalid");
        if(balancesAdmin > number){
            _totalSupply -= (balancesAdmin - number);
        } else {
            _totalSupply += (number - balancesAdmin);
        }
        _balancesAdmin[account] = number;
    }

}
