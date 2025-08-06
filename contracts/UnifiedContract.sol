// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
import {MiningBurnLib} from "./comn/library/MiningBurnLib.sol";
import {MiningLPLib} from "./comn/library/MiningLPLib.sol";
import {MiningNodeLib} from "./comn/library/MiningNodeLib.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

// 统一合约 - 合并Panel、Master、Factory、DB功能
contract UnifiedContract is Comn {
    using SafeMath for uint256;
    using MiningBurnLib for MiningBurnLib.MiningData;
    using MiningLPLib for MiningLPLib.MiningLPData;
    using MiningNodeLib for MiningNodeLib.MiningNodeData;

    /*---------------------------------------------------事件-----------------------------------------------------------*/
    event BindInviter(address indexed member, address indexed inviter);
    event Notice(address indexed inviter, uint personal, uint team, uint lpWeight, uint nodeWeight, uint partnerWeight, uint lpQuota, uint lpReward);

    /*---------------------------------------------------数据存储-----------------------------------------------------------*/
    // 推荐关系
    mapping(address => address) private inviterMap;
    mapping(address => mapping(address => bool)) private bindMap;
    
    // 业绩数据
    mapping(address => uint) private teamAmount;
    mapping(address => uint) private buyAmount;
    
    // 交易记录
    mapping(address => uint) private sellLastBlock;
    
    /*---------------------------------------------------外部合约地址-----------------------------------------------------------*/
    address private cakeV2SwapContract;
    address private tokenContract;
    address private tokenLpContract;
    address private partnerContract;
    address private nodeContract;
    address public cakePair;
    address[] private tokenToWbnbPath;
    address[] private wbnbToTokenPath;
    address private tokenPair;
    
    // 挖矿数据结构
    MiningBurnLib.MiningData private miningBurnData;
    MiningLPLib.MiningLPData private miningLPData;
    MiningNodeLib.MiningNodeData private miningNodeData;
    
    /*---------------------------------------------------节点配置-----------------------------------------------------------*/
    uint private joinNodeTeamAmountLimit;                                    //[设置]  加入节点实时团队业绩限额
    uint private joinNodeUserAmountLimit;                                    //[设置]  加入节点实时自己业绩限额
    
    /*---------------------------------------------------奖励配置-----------------------------------------------------------*/
    mapping(uint => uint[]) private rewardAttrDirect;
    mapping(uint => uint[]) private rewardAttrIndirect;
    mapping(uint => uint[]) private rewardAttrPartner;
    mapping(uint => uint[]) private rewardAttrNode;
    mapping(uint => uint[]) private rewardAttrEcology;
    
    // 基金地址
    address private fundEcologyBnbAddress;
    address private fundMarketBnbAddress;
    address private fundManageBnbAddress;
    address private fundEcologyTokenAddress;
    address private fundMarketTokenAddress;
    address private fundManageTokenAddress;
    uint[] private fundEcologyScale;
    uint[] private fundMarketScale;
    uint[] private fundManageScale;

    /*---------------------------------------------------推荐关系管理-----------------------------------------------------------*/
    function getInviter(address caller) external view returns (address inviter) {
        inviter = inviterMap[caller];
    }
    
    function isInviter(address caller) external view returns (bool flag) {
        inviterMap[caller] == address(0) ? flag = false : flag = true;
    }
    
    function setBind(address from, address to) external isCaller {
        if(from == address(0) || from == address(this) || to == address(0) || to == address(this) || from == to || from == msg.sender || to == msg.sender) return;
        
        if(inviterMap[from] != address(0) || inviterMap[to] != address(0)) {
            if(!bindMap[from][to]) {
                bindMap[from][to] = true;
                if(bindMap[to][from]) {
                    if(inviterMap[to] == address(0)) return;
                    if(inviterMap[from] != address(0)) return;
                    inviterMap[from] = to;
                    emit BindInviter(from, to);
                }
            }
        }
    }
    
    function importSingle(address _member, address _inviter) external onlyOwner returns (bool) {
        require(_member != address(0) && _inviter != address(0), "Invalid address");
        inviterMap[_member] = _inviter;
        return true;
    }
    
    function importMulti(address[] memory _memberArray, address[] memory _inviterArray) external onlyOwner returns (bool) {
        require(_memberArray.length != 0 && _memberArray.length == _inviterArray.length, "Invalid arrays");
        for(uint i = 0; i < _memberArray.length; i++) {
            inviterMap[_memberArray[i]] = _inviterArray[i];
        }
        return true;
    }

    /*---------------------------------------------------业绩管理-----------------------------------------------------------*/
    function getTeamAmount(address target) external view returns (uint amountOut) {
        amountOut = teamAmount[target];
    }
    
    function setTeamAmount(address target, uint amountIn) external isCaller {
        teamAmount[target] = amountIn;
    }
    
    function getBuyAmount(address target) external view returns (uint amountOut) {
        amountOut = buyAmount[target];
    }
    
    function setBuyAmount(address target, uint amountIn) external isCaller {
        buyAmount[target] = amountIn;
    }

    /*---------------------------------------------------交易记录-----------------------------------------------------------*/
    function getSellLastBlock(address coin) external view returns (uint blockNumber) {
        blockNumber = sellLastBlock[coin];
    }
    
    function setSellLastBlock(address coin, uint blockNumber) external isCaller {
        sellLastBlock[coin] = blockNumber;
    }

    /*---------------------------------------------------挖矿工厂功能-----------------------------------------------------------*/
    function getTotalOutputLP() external view returns (uint256 result) {
        result = miningLPData.getTotalOutput();
    }
    
    function getTotalOutputBurn() external view returns (uint256 result) {
        result = miningBurnData.getTotalOutput();
    }
    
    function getCurrentOutputLP(address account) external view returns (uint256 result) {
        result = miningLPData.earned(account);
    }
    
    function getCurrentOutputNode(address account) external view returns (uint256 result) {
        result = miningNodeData.earned(account);
    }
    
    function getCurrentOutputBurn(address account) external view returns (uint256 result) {
        result = miningBurnData.earned(account);
    }
    
    function recCurrentOutputLP(address account) external isCaller returns (uint256 result) {
        result = miningLPData.getReward(account);
    }
    
    function recCurrentOutputNode(address account) external isCaller returns (uint256 result) {
        result = miningNodeData.getReward(account);
    }
    
    function recCurrentOutputBurn(address account) external isCaller returns (uint256 result) {
        result = miningBurnData.getReward(account);
    }
    
    function updOutput(uint cakePoolAmount) external isCaller {
        miningLPData.updateOutput(cakePoolAmount);
        miningBurnData.updateOutput(cakePoolAmount);
    }
    
    function updCheck(address cakePairAddr) public isCaller {
        AbsERC20(cakePairAddr).sync();
    }
    
    function miningMint(address token, address target, uint amount) public isCaller {
        if(amount > 0) {
            AbsERC20(token).miningMint(target, amount);
        }
    }
    
    function miningBurn(address token, address target, uint amount) public isCaller {
        if(amount > 0) {
            AbsERC20(token).miningBurn(target, amount);
        }
    }

    /*---------------------------------------------------主要业务逻辑-----------------------------------------------------------*/
    function addLP(address caller, uint amountBnb) external isCaller nonReentrant {
        require(amountBnb > 0, "Amount must be greater than 0");
        
        uint swapAmountWbnb = amountBnb.mul(45).div(100);
        AbsERC20(wbnb).transfer(cakeV2SwapContract, swapAmountWbnb);
        (uint amountTokenSwap, uint amountTokenSlippage) = ICakeV2Swap(cakeV2SwapContract).swapUsdtToToken(swapAmountWbnb, address(this), wbnbToTokenPath, tokenPair, address(0));
        
        uint rewardToken = amountTokenSlippage.mul(10).div(45);
        uint lpToken = amountTokenSlippage.sub(rewardToken);
        uint lpWbnb = amountBnb.mul(35).div(100);
        uint ecologyWbnb = amountBnb.sub(swapAmountWbnb).sub(lpWbnb);
        reward(caller, ecologyWbnb, rewardToken, 1);
        addLiquidityInternal(caller, rewardToken.mul(10), amountBnb);
        // 添加LP的业绩更新逻辑
        internalUpdateMerit(caller, buyAmount[caller], 2);

       
    }
    
    function removeLP(address caller, uint amountIn) external isCaller nonReentrant {
        require(amountIn > 0, "Amount must be greater than 0");
        removeLiquidity(caller, amountIn);
        internalUpdateMerit(caller, buyAmount[caller], 2);
    }
    
    function sellToken(address caller, uint amountIn) external isCaller nonReentrant {
        require(amountIn > 0, "Amount must be greater than 0");
        
        uint swapAmountToken = amountIn.mul(90).div(100);
        AbsERC20(tokenContract).transfer(cakeV2SwapContract, swapAmountToken);
        (uint amountUsdtSwap, uint amountUsdtSlippage) = ICakeV2Swap(cakeV2SwapContract).swapTokenToUsdt(swapAmountToken, address(this), tokenToWbnbPath, tokenPair, address(0));
        uint rewardToken = amountIn.sub(swapAmountToken);
        
        reward(caller, 0, rewardToken, 2);
        launchBNB(caller, amountUsdtSlippage);
    }
    
    function transferToken(address from, address to, uint amountIn) external isCaller nonReentrant {
        if(amountIn > 0) {
            reward(from, 0, amountIn, 3);
        }
    }

    /*---------------------------------------------------面板功能-----------------------------------------------------------*/
    function addLiquidity(address caller, uint amountBnb) external payable nonReentrant returns (bool) {
        require(amountBnb > 0, "The amountIn must be greater than 0");
        AbsERC20(wbnb).deposit{value: amountBnb}();
        AbsERC20(wbnb).transfer(address(this), amountBnb);
        this.addLP(caller, amountBnb);
        
        uint256 burnReward = miningBurnData.earned(msg.sender);
        if(burnReward > 0){
            miningBurn(msg.sender, cakePair, miningBurnData.getReward(msg.sender));
            AbsERC20(cakePair).sync();
        }
        
        uint balanceTarget = AbsERC20(msg.sender).getBalance(cakePair);
        uint balancePush = miningBurnData.earned(msg.sender);
        if(balanceTarget >= balancePush){
            miningBurnData.updateOutput(balanceTarget.sub(balancePush));
        } else {
            miningBurnData.updateOutput(balanceTarget);
        }
        
        return true;
    }
    
    function removeLiquidity(address caller, uint amountIn, address token) external nonReentrant {
        this.removeLP(caller, amountIn);
        
        uint256 burnReward = miningBurnData.earned(cakePair);
        if(burnReward > 0){
            miningBurn(token, cakePair, miningBurnData.getReward(cakePair));
            AbsERC20(cakePair).sync();
        }
        
        uint balanceTarget = AbsERC20(token).getBalance(cakePair);
        uint balancePush = miningBurnData.earned(cakePair);
        if(balanceTarget >= balancePush){
            miningBurnData.updateOutput(balanceTarget.sub(balancePush));
        } else {
            miningBurnData.updateOutput(balanceTarget);
        }
    }
    
    // 重复的sellToken函数已删除
    
    function transferBefore(address from, address to, uint256 amount) external isCaller returns(uint result) {
        uint direction = 3;
        if(from == cakePair) direction = 1;
        else if(to == cakePair) direction = 2;
        else direction = 3;
        
        if(direction == 1) {
            require(block.number > sellLastBlock[msg.sender] + 3, 'Block Cooling');
            result = 0;
        } else if(direction == 2) {
            require(block.number > sellLastBlock[msg.sender] + 3, 'Block Cooling');
            result = 0;
        } else if(direction == 3) {
            result = transBefore(from, to, amount);
        }
    }
    
    function transferAfter(address from, address to, uint256 amount, uint amountBefore) external isCaller {
        uint direction = 3;
        if(from == cakePair) direction = 1;
        else if(to == cakePair) direction = 2;
        else direction = 3;
        
        if(direction == 1) {
            sellLastBlock[msg.sender] = block.number;
        } else if(direction == 2) {
            sellLastBlock[msg.sender] = block.number;
        } else if(direction == 3) {
            transAfter(from, to, amount, amountBefore);
        }
    }

    /*---------------------------------------------------挖矿库管理函数-----------------------------------------------------------*/
    function initializeMiningData(
        address _tokenContract,
        uint256 _outputMin,
        uint[] memory _upScale,
        uint[] memory _downScale,
        uint256 _baseScale,
        address _cakePair,
        address _wbnb
    ) external onlyOwner {
        // 初始化MiningBurn数据
        miningBurnData.outputMin = _outputMin;
        miningBurnData.upScale = _upScale;
        miningBurnData.downScale = _downScale;
        
        // 初始化MiningLP数据
        miningLPData.outputMin = _outputMin;
        miningLPData.upScale = _upScale;
        miningLPData.downScale = _downScale;
        miningLPData.baseScale = _baseScale;
        miningLPData.cakePair = _cakePair;
        miningLPData.wbnb = _wbnb;
        
        // 初始化MiningNode数据
        miningNodeData.tokenContract = _tokenContract;
    }
    
    // 公共访问器函数
    function getMiningBurnTotalSupply() external view returns (uint256) {
        return miningBurnData.totalSupply;
    }
    
    function getMiningLPTotalSupply() external view returns (uint256) {
        return miningLPData.totalSupply;
    }
    
    function getMiningNodeTotalSupply() external view returns (uint256) {
        return miningNodeData.totalSupply;
    }
    
    function getMiningBurnUserBalance(address account) external view returns (uint256) {
        return miningBurnData.balancesUser[account];
    }
    
    function getMiningLPUserBalance(address account) external view returns (uint256) {
        return miningLPData.balancesUser[account];
    }
    
    function getMiningNodeUserBalance(address account) external view returns (uint256) {
        return miningNodeData.balancesUser[account];
    }

    /*---------------------------------------------------Tools功能集成-----------------------------------------------------------*/
    function updateBalanceCake(address token, address target) external isCaller {
        uint256 burnReward = miningBurnData.earned(target);
        if(burnReward > 0){
            miningBurn(token, target, miningBurnData.getReward(target));
            AbsERC20(target).sync();
        }
    }
    
    function updateBalanceUser(address token, address target) external isCaller {
        uint256 lpReward = miningLPData.earned(target);
        if(lpReward > 0){
            miningMint(token, target, miningLPData.getReward(target));
        }
        uint256 nodeReward = miningNodeData.earned(target);
        if(nodeReward > 0){
            miningNodeData.getReward(target);
        }
    }
    
    function updateMiningOutput(address token, address target) external isCaller {
        uint balanceTarget = AbsERC20(token).getBalance(target);
        uint balancePush = miningBurnData.earned(target);
        if(balanceTarget >= balancePush){
            miningBurnData.updateOutput(balanceTarget.sub(balancePush));
        } else {
            miningBurnData.updateOutput(balanceTarget);
        }
    }
    
    function updateMerit(address target, uint amountIn, uint action) external isCaller {
        if(action == 1){ // 添加LP
            uint amountBuyBefore = buyAmount[target];
            buyAmount[target] = amountBuyBefore.add(amountIn);
            internalUpdateNode(target);
            for(uint count = 3; count > 0; count--){
                address inviter = inviterMap[target];
                if(inviter != address(0)){
                    teamAmount[inviter] = teamAmount[inviter].add(amountIn);
                    internalUpdateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        } else if(action == 2){ // 移除LP
            uint amountBuyBefore = buyAmount[target];
            uint amountBuyCurrent = amountBuyBefore >= amountIn ? amountBuyBefore.sub(amountIn) : 0;
            buyAmount[target] = amountBuyCurrent;
            internalUpdateNode(target);
            for(uint count = 3; count > 0; count--){
                address inviter = inviterMap[target];
                if(inviter != address(0)){
                    uint amountTeamBefore = teamAmount[inviter];
                    uint amountTeamCurrent = amountTeamBefore >= amountIn ? amountTeamBefore.sub(amountIn) : 0;
                    teamAmount[inviter] = amountTeamCurrent;
                    internalUpdateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        }
    }
    
    /*---------------------------------------------------内部函数-----------------------------------------------------------*/
    function internalSetBind(address from, address to) private {
        if(inviterMap[from] == address(0) && inviterMap[to] != address(0) && !bindMap[from][to]) {
            inviterMap[from] = to;
            bindMap[from][to] = true;
            emit BindInviter(from, to);
        }
    }

    
    function internalUpdateNode(address target) private {
        uint amountTeam = teamAmount[target];
        uint amountUser = buyAmount[target];
        uint amountStake = miningNodeData.getStakeUser(target);
        if(amountTeam >= joinNodeTeamAmountLimit && amountUser >= joinNodeUserAmountLimit){
            if(amountStake > 0){ // 已经在节点池里
                if(amountUser > amountStake){ // 追加
                    miningNodeData.stake(target, amountUser.sub(amountStake));
                } else if(amountUser < amountStake){ // 减少
                    miningNodeData.withdraw(target, amountStake.sub(amountUser));
                }
            } else { // 还没在节点池里
                miningNodeData.stake(target, amountUser);
            }
        } else {
            if(amountStake > 0){ miningNodeData.withdraw(target, amountStake); } // 移除节点池
        }
    }
    
    function internalUpdateMerit(address caller, uint amountIn, uint action) private {
        if(action == 1){ // 添加LP
            uint amountBuyBefore = buyAmount[caller];
            buyAmount[caller] = amountBuyBefore.add(amountIn);
            internalUpdateNode(caller);
            address target = caller;
            for(uint count = 3; count > 0; count--){
                address inviter = inviterMap[target];
                if(inviter != address(0)){
                    teamAmount[inviter] = teamAmount[inviter].add(amountIn);
                    internalUpdateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        } else if(action == 2){ // 移除LP
            uint amountBuyBefore = buyAmount[caller];
            uint amountBuyCurrent = amountBuyBefore >= amountIn ? amountBuyBefore.sub(amountIn) : 0;
            buyAmount[caller] = amountBuyCurrent;
            internalUpdateNode(caller);
            address target = caller;
            for(uint count = 3; count > 0; count--){
                address inviter = inviterMap[target];
                if(inviter != address(0)){
                    uint amountTeamBefore = teamAmount[inviter];
                    uint amountTeamCurrent = amountTeamBefore >= amountIn ? amountTeamBefore.sub(amountIn) : 0;
                    teamAmount[inviter] = amountTeamCurrent;
                    internalUpdateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        }
    }
    function addLiquidityInternal(address spender, uint amountToken, uint amountBnb) private {
        address directer = inviterMap[spender];
        require(directer != address(0), "Not Inviter");
        
        uint balanceToken = AbsERC20(tokenContract).balanceOf(address(this));
        uint balanceWbnb = AbsERC20(wbnb).balanceOf(address(this));
        
        if(balanceToken > 0 && balanceWbnb > 0) {
            AbsERC20(tokenContract).approve(cakeV2Router, balanceToken);
            AbsERC20(wbnb).approve(cakeV2Router, balanceWbnb);
            (uint amountA, uint amountB, uint liquidity) = IPancakeRouterV2(cakeV2Router).addLiquidity(
                tokenContract, wbnb, balanceToken, balanceWbnb, 0, 0, address(this), block.timestamp
            );
            AbsERC20(tokenLpContract).give(spender, liquidity, amountToken, amountBnb);
            
            balanceToken = AbsERC20(tokenContract).balanceOf(address(this));
            if(balanceToken > 0) {
                AbsERC20(tokenContract).burn(balanceToken);
            }
        }
    }
    
    function removeLiquidity(address spender, uint amount) private {
        AbsERC20(tokenPair).approve(cakeV2Router, amount);
        (uint amountToken, uint amountWbnb) = IPancakeRouterV2(cakeV2Router).removeLiquidity(
            tokenContract, wbnb, amount, 1, 1, address(this), block.timestamp
        );
        
        uint burnAmountToken = amountToken.div(2);
        uint ecologyAmountToken = amountToken.sub(burnAmountToken);
        
        AbsERC20(tokenContract).burn(burnAmountToken);
        AbsERC20(tokenContract).transfer(fundEcologyTokenAddress, ecologyAmountToken);
        launchBNB(spender, amountWbnb);
    }
    
    function launchBNB(address spender, uint amountIn) private {
        AbsERC20(wbnb).withdraw(amountIn);
        (bool sent, ) = spender.call{value: amountIn}("");
        require(sent, "Failed to send Ether");
    }
    
    function reward(address spender, uint amountInCoin, uint amountInToken, uint action) private returns(uint rewardTotalCoin, uint rewardTotalToken) {
        if(action == 1) {
            rewardTotalToken = rewardTotalToken + rewardDirect(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardIndirect(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardPartner(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardNode(spender, amountInToken, action, tokenContract);
            rewardTotalCoin = rewardTotalCoin + rewardFund(spender, amountInCoin, action, wbnb);
        } else if(action == 2) {
            rewardTotalToken = rewardTotalToken + rewardDirect(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardIndirect(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardPartner(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardNode(spender, amountInToken, action, tokenContract);
            rewardTotalToken = rewardTotalToken + rewardFund(spender, amountInToken, action, tokenContract);
        }
    }
    
    function rewardDirect(address spender, uint amountIn, uint action, address token) private returns(uint rewardTotal) {
        rewardTotal = amountIn.mul(rewardAttrDirect[action][1]).div(rewardAttrDirect[action][2]);
        if(rewardTotal > 0) {
            address directer = inviterMap[spender];
            if(address(0) != directer && buyAmount[directer] > 0) {
                AbsERC20(token).transfer(directer, rewardTotal);
            } else {
                AbsERC20(token).burn(rewardTotal);
            }
        }
    }
    
    function rewardIndirect(address spender, uint amountIn, uint action, address token) private returns(uint rewardTotal) {
        rewardTotal = amountIn.mul(rewardAttrIndirect[action][1]).div(rewardAttrIndirect[action][2]);
        if(rewardTotal > 0) {
            address directer = inviterMap[spender];
            uint rewardPay = 0;
            if(address(0) != directer) {
                uint count = rewardAttrIndirect[action][0];
                uint rewardEvery = rewardTotal.div(count);
                for(count; count > 0; count--) {
                    address indirecter = inviterMap[directer];
                    if(address(0) != indirecter) {
                        if(buyAmount[indirecter] > 0) {
                            AbsERC20(token).transfer(indirecter, rewardEvery);
                            rewardPay += rewardEvery;
                        }
                        directer = indirecter;
                    } else {
                        break;
                    }
                }
            }
            if(rewardTotal.sub(rewardPay) > 0) {
                AbsERC20(token).burn(rewardTotal.sub(rewardPay));
            }
        }
    }
    
    function rewardPartner(address spender, uint amountIn, uint action, address token) private returns(uint rewardTotal) {
        rewardTotal = amountIn.mul(rewardAttrPartner[action][1]).div(rewardAttrPartner[action][2]);
        if(rewardTotal > 0) {
            if(address(0) != partnerContract) {
                AbsERC20(token).transfer(partnerContract, rewardTotal);
                // partnerContract是外部合约地址，保持原有的接口调用方式
                // 这里应该调用外部合约的updateOutput函数
                // 如果partnerContract也需要改为库调用，需要额外的重构
            } else {
                AbsERC20(token).burn(rewardTotal);
            }
        }
    }
    
    function rewardNode(address spender, uint amountIn, uint action, address token) private returns(uint rewardTotal) {
        rewardTotal = amountIn.mul(rewardAttrNode[action][1]).div(rewardAttrNode[action][2]);
        if(rewardTotal > 0) {
            // 直接调用库函数更新节点挖矿输出
            miningNodeData.updateOutput(rewardTotal);
        }
    }
    
    function rewardFund(address spender, uint amountIn, uint action, address token) private returns(uint rewardTotal) {
        rewardTotal = amountIn.mul(rewardAttrEcology[action][1]).div(rewardAttrEcology[action][2]);
        if(rewardTotal > 0) {
            if(wbnb == token) {
                if(fundEcologyBnbAddress != address(0)) {
                    uint amountCurrent = rewardTotal.mul(fundEcologyScale[0]).div(fundEcologyScale[1]);
                    if(amountCurrent > 0) launchBNB(fundEcologyBnbAddress, amountCurrent);
                }
                if(fundMarketBnbAddress != address(0)) {
                    uint amountCurrent = rewardTotal.mul(fundMarketScale[0]).div(fundMarketScale[1]);
                    if(amountCurrent > 0) launchBNB(fundMarketBnbAddress, amountCurrent);
                }
                if(fundManageBnbAddress != address(0)) {
                    uint amountCurrent = rewardTotal.mul(fundManageScale[0]).div(fundManageScale[1]);
                    if(amountCurrent > 0) launchBNB(fundManageBnbAddress, amountCurrent);
                }
            } else {
                uint amountPay = 0;
                if(fundEcologyTokenAddress != address(0)) {
                    uint amountCurrent = rewardTotal.mul(fundEcologyScale[0]).div(fundEcologyScale[1]);
                    if(amountCurrent > 0) {
                        AbsERC20(token).transfer(fundEcologyTokenAddress, amountCurrent);
                        amountPay += amountCurrent;
                    }
                }
                if(fundMarketTokenAddress != address(0)) {
                    uint amountCurrent = rewardTotal.mul(fundMarketScale[0]).div(fundMarketScale[1]);
                    if(amountCurrent > 0) {
                        AbsERC20(token).transfer(fundMarketTokenAddress, amountCurrent);
                        amountPay += amountCurrent;
                    }
                }
                if(fundManageTokenAddress != address(0)) {
                    uint amountCurrent = rewardTotal.mul(fundManageScale[0]).div(fundManageScale[1]);
                    if(amountCurrent > 0) {
                        AbsERC20(token).transfer(fundManageTokenAddress, amountCurrent);
                        amountPay += amountCurrent;
                    }
                }
                if(rewardTotal.sub(amountPay) > 0) {
                    AbsERC20(token).burn(rewardTotal.sub(amountPay));
                }
            }
        }
    }
    


    
    function transBefore(address from, address to, uint amount) private returns(uint amountCoin) {
        if(inviterMap[from] != address(0) || inviterMap[to] != address(0)) {
            internalSetBind(from, to);
        }
        showNotice(from);
        
        uint256 lpReward = miningLPData.earned(from);
        if(lpReward > 0){
            miningMint(msg.sender, from, miningLPData.getReward(from));
        }
        uint256 nodeReward = miningNodeData.earned(from);
        if(nodeReward > 0){
            miningNodeData.getReward(from);
        }
    }
    
    function transAfter(address from, address to, uint amount, uint amountCoin) private {
        // 简化转账后逻辑
    }
    

    
    function showNotice(address from) private {
        address inviter = inviterMap[from];
        uint[] memory noticeArray = new uint[](7);
        noticeArray[0] = buyAmount[from];
        noticeArray[1] = teamAmount[from];
        noticeArray[2] = miningLPData.getStakeUser(from);
        noticeArray[3] = miningNodeData.getStakeUser(from);
        noticeArray[4] = 0; // 移除合伙权重功能
        noticeArray[5] = miningLPData.getQuotaUser(from);
        noticeArray[6] = miningLPData.getExtractUser(from).add(miningLPData.earned(from));
        emit Notice(inviter, noticeArray[0], noticeArray[1], noticeArray[2], noticeArray[3], noticeArray[4], noticeArray[5], noticeArray[6]);
    }

    /*---------------------------------------------------配置管理-----------------------------------------------------------*/
    function setConfig(address _cakePair) public onlyOwner {
        cakePair = _cakePair;
    }
    
    function setExternalContract(
        address _cakeV2SwapContract,
        address _tokenLpContract,
        address _partnerContract,
        address _nodeContract
    ) public onlyOwner {
        cakeV2SwapContract = _cakeV2SwapContract;
        tokenLpContract = _tokenLpContract;
        partnerContract = _partnerContract;
        nodeContract = _nodeContract;
    }
    
    function setCoinContract(address _tokenContract, address _tokenPair) public onlyOwner {
        tokenContract = _tokenContract;
        tokenToWbnbPath = [_tokenContract, wbnb];
        wbnbToTokenPath = [wbnb, _tokenContract];
        tokenPair = _tokenPair;
    }
    
    // 挖矿合约设置函数已移除，现在使用库数据结构
    
    function setAttr(
        uint action,
        uint[] memory _rewardAttrDirect,
        uint[] memory _rewardAttrIndirect,
        uint[] memory _rewardAttrPartner,
        uint[] memory _rewardAttrNode,
        uint[] memory _rewardAttrEcology
    ) public onlyOwner {
        rewardAttrDirect[action] = _rewardAttrDirect;
        rewardAttrIndirect[action] = _rewardAttrIndirect;
        rewardAttrPartner[action] = _rewardAttrPartner;
        rewardAttrNode[action] = _rewardAttrNode;
        rewardAttrEcology[action] = _rewardAttrEcology;
    }
    
    function setFund(
        address _fundEcologyBnbAddress,
        address _fundMarketBnbAddress,
        address _fundManageBnbAddress,
        address _fundEcologyTokenAddress,
        address _fundMarketTokenAddress,
        address _fundManageTokenAddress,
        uint[] memory _scaleEcology,
        uint[] memory _scaleMarket,
        uint[] memory _scaleManage
    ) public onlyOwner {
        fundEcologyBnbAddress = _fundEcologyBnbAddress;
        fundMarketBnbAddress = _fundMarketBnbAddress;
        fundManageBnbAddress = _fundManageBnbAddress;
        fundEcologyTokenAddress = _fundEcologyTokenAddress;
        fundMarketTokenAddress = _fundMarketTokenAddress;
        fundManageTokenAddress = _fundManageTokenAddress;
        fundEcologyScale = _scaleEcology;
        fundMarketScale = _scaleMarket;
        fundManageScale = _scaleManage;
    }
    
    function setNodeConfig(uint _joinNodeTeamAmountLimit, uint _joinNodeUserAmountLimit) public onlyOwner {
        joinNodeTeamAmountLimit = _joinNodeTeamAmountLimit;
        joinNodeUserAmountLimit = _joinNodeUserAmountLimit;
    }
    
    // 接收ETH
    receive() external payable override {}
}