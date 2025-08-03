// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IMining} from "./interface/IMining.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import {Comn} from "./comn/Comn.sol";

contract MiningBurn is Comn,IMining {
    using SafeMath for uint256;
    
    uint256 public updateTime;                                  //最近一次更新时间
    uint256 public rewardPerTokenStored;                        //每单位 token 奖励数量, 此值放大了1e18倍
    mapping(address => uint256) public userRewardPerTokenPaid;  //已采集量, 此值放大了1e18倍
    mapping(address => uint256) public rewards;                 //余额

    uint256 public _totalOutput;                                //全网总产出量
    uint256 public _totalSupply;                                //全网总质押算力
    mapping(address => uint256) private _balancesUser;          //地址总质押算力
    mapping(address => uint256) private _balancesAdmin;         //系统总质押算力

    
    // 更新挖矿奖励
    modifier updateReward(address account) {
        _totalOutput += rewardLastToken();           // 更新 | 全网 | 总产出
        rewardPerTokenStored = rewardPerToken();     // 更新 | 全网 | 单币总产出
        updateTime = getNowTime();                   // 更新 | 全网 | 最后更新时间
        if (account != address(0)) {
            rewards[account] = _earned(account, rewardPerTokenStored); // 更新 | 个人 | 收益余额
            userRewardPerTokenPaid[account] = rewardPerTokenStored;    // 更新 | 个人 | 收益时刻
        }
        _;
    }

    // 单币总产量
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) { return rewardPerTokenStored; }
        // 最后一个区间的单产币量
        uint tmpPrice = rewardLastToken() * 1e18 / _totalSupply;
        return rewardPerTokenStored + tmpPrice;
    }

    // 最后一个区间的总产币量
    function rewardLastToken() public view returns (uint256) {
        return (getNowTime() - updateTime) * miningRateSecond;
    }

    function _earned(address account, uint _rewardPerTokenStored) public view returns (uint256) {
        return rewards[account] + (_balancesUser[account] + _balancesAdmin[account]) * (_rewardPerTokenStored - userRewardPerTokenPaid[account]) / 1e18;
    }

    function getNowTime() public view returns (uint256) {
        uint blockTime = block.timestamp;
        if (updateTime > blockTime){
            return updateTime;
        }
        if (miningEndTime < blockTime) {
            return miningEndTime;
        }
        return blockTime;
    }

    /*---------------------------------------------------接口-----------------------------------------------------------*/
    function earned(address account) public view virtual returns (uint256) {
        return _earned(account, rewardPerToken());
    }

    function getReward(address account) public isCaller updateReward(account) virtual returns (uint256) {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
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

    function updateOutput(uint cakePoolAmount) external isCaller virtual returns(uint outputToWei){
        if(getCaller(msg.sender) || msg.sender == getOwner()){
            if(cakePoolAmount >= outputMin){
                outputToWei = cakePoolAmount.mul(upScale[0]).div(upScale[1]).div(86400);
            } else {
                outputToWei = cakePoolAmount.mul(downScale[0]).div(downScale[1]).div(86400);
            }
            if(outputToWei != miningRateSecond){
                _totalOutput += rewardLastToken();             // 更新 | 全网 | 总产出
                rewardPerTokenStored = rewardPerToken();       // 更新 | 全网 | 单币总产出
                updateTime = getNowTime();                     // 更新 | 全网 | 最后更新时间
                miningRateSecond = outputToWei;
            } else {
                outputToWei = miningRateSecond;
            }
        }
    }

    function getTotalOutput() public view virtual returns (uint256) { return _totalOutput; }
    function getStakeUser(address account) public view virtual returns (uint256) { return _balancesUser[account]; }
    function getStakeAdmin(address account) public view virtual returns (uint256) { return _balancesAdmin[account]; }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    uint private outputMin;                                     // [设置]  最低产出限额,底池达到最低额度则停止产出
    uint[] private upScale;                                     // [设置]  限额之上,产出比例 (Index:0分子,1分母) 
    uint[] private downScale;                                   // [设置]  限额之下,产出比例 (Index:0分子,1分母) 
    function setConfig(uint _outputMin,uint[] memory _upScale,uint[] memory _downScale) external onlyOwner {
        outputMin = _outputMin;
        upScale = _upScale;
        downScale = _downScale;
    }

    uint public miningEndTime;                                  // [设置]  截止时间 (单位:秒)
    function setEndTime(uint _miningEndTime) external onlyOwner updateReward(address(0)){ miningEndTime = _miningEndTime;}

    uint public miningRateSecond;                               // [设置]  每秒产量 (单位:秒)
    function setOutput(uint outputToWei) external onlyOwner updateReward(address(0)){ miningRateSecond = outputToWei;}

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