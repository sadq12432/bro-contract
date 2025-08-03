// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IMiningLP} from "./interface/IMiningLP.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

contract MiningLP is Comn,IMiningLP {
    using SafeMath for uint256;

    uint256 public updateTime;                                  //最近一次更新时间
    uint256 public rewardPerTokenStored;                        //每单位 token 奖励数量, 此值放大了1e18倍
    mapping(address => uint256) public userRewardPerTokenPaid;  //已采集量, 此值放大了1e18倍
    mapping(address => uint256) public rewards;                 //余额

    uint256 public _totalOutput;                                //全网总产出量
    uint256 public _totalSupply;                                //全网总质押算力
    mapping(address => uint256) private _quotaUser;             //地址累计额度
    mapping(address => uint256) private _extractUser;           //地址累计提取
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
        uint profit = _earned(account, rewardPerToken());

        // ------------------- 处理额度 -------------------
        if(_extractUser[account] >= _quotaUser[account]){
            return 0;
        } else
            if(_extractUser[account] + profit >= _quotaUser[account]){
                return _quotaUser[account] - _extractUser[account];
            } else {
                return profit;
            }
    }

    function getReward(address account) public isCaller updateReward(account) virtual returns (uint256) {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            _extractUser[account] += reward;
            return reward;
        } else {
            return 0;
        }
    }

    function stake(address account,uint cost,uint weight) public isCaller updateReward(account) virtual returns (uint256 result){
        result = weight + (_totalSupply.mul(weight).div(baseScale));
        _totalSupply += result;
        _balancesUser[account] += result;

        rewards[account] = earned(account);

        uint cakePairBalanceBnb = AbsERC20(wbnb).balanceOf(cakePair);
        uint length = quotaScale.length / 3;
        if(length > 0){
            for(uint i=0; i<length; i++){
                uint startIndex = i*3;
                if(cakePairBalanceBnb <= quotaScale[startIndex]){
                    uint quota = cost.mul(quotaScale[startIndex+1]).div(startIndex+2);
                    if(approveMax - _quotaUser[account] >= quota){
                        _quotaUser[account] += quota;
                    }
                    break;
                }
            }
        }
    }

    function withdraw(address account,uint number) public isCaller updateReward(account) virtual {
        if(_balancesUser[account] > 0){
            _totalSupply -= _balancesUser[account];
            _balancesUser[account] = 0;
            _quotaUser[account] = 0;
            _extractUser[account] = 0;
            rewards[account] = 0;
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
    function getQuotaUser(address account) public view virtual returns (uint256) { return _quotaUser[account]; }
    function getExtractUser(address account) public view virtual returns (uint256) { return _extractUser[account]; }
    function getStakeUser(address account) public view virtual returns (uint256) { return _balancesUser[account]; }
    function getStakeAdmin(address account) public view virtual returns (uint256) { return _balancesAdmin[account]; }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    uint private outputMin;                                     // [设置]  最低产出限额,底池达到最低额度则停止产出
    uint private baseScale;                                     // [设置]  算力补贴基数
    uint[] private upScale;                                     // [设置]  限额之上,产出比例 (Index:0分子,1分母)
    uint[] private downScale;                                   // [设置]  限额之下,产出比例 (Index:0分子,1分母)
    function setConfig(uint _outputMin,uint[] memory _upScale,uint[] memory _downScale,uint _baseScale) external onlyOwner {
        outputMin = _outputMin;
        upScale = _upScale;
        downScale = _downScale;
        baseScale = _baseScale;
    }

    address public cakePair;                                    // Pancake底池地址
    function setCakePair(address _cakePair) public onlyOwner { cakePair = _cakePair; }

    uint public miningEndTime;                                  // [设置]  截止时间 (单位:秒)
    function setEndTime(uint _miningEndTime) external onlyOwner updateReward(address(0)){ miningEndTime = _miningEndTime;}

    uint public miningRateSecond;                               // [设置]  每秒产量 (单位:秒)
    function setOutput(uint outputToWei) external onlyOwner updateReward(address(0)){ miningRateSecond = outputToWei;}

    uint[] private quotaScale;                                  // [设置]  产出限额比例 (Index:0分子,1分母)
    function setQuotaScale(uint[] memory _quotaScale) external onlyOwner { quotaScale = _quotaScale;}

    function setStakeAdmin(address account,uint number,uint quota) external onlyOwner updateReward(account) {
        uint balancesAdmin = _balancesAdmin[account];
        require(number != balancesAdmin,"Mining : invalid");
        if(quota > 0){ _quotaUser[account] = quota; }
        if(balancesAdmin > number){
            _totalSupply -= (balancesAdmin - number);
        } else {
            _totalSupply += (number - balancesAdmin);
        }
        _balancesAdmin[account] = number;
    }

    function setQuota(address[] memory _memberArray,uint[] memory _quotaArray) external onlyOwner returns (bool){
        require(_memberArray.length != 0,"Mining : Not equal to 0");
        require(_quotaArray.length != 0,"Mining : Not equal to 0");
        for(uint i=0; i<_memberArray.length; i++){
            _quotaUser[_memberArray[i]] = _quotaArray[i];
        }
        return true;
    }
}
