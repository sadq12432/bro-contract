// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
import {IMining} from "./interface/IMining.sol";
import {IMiningLP} from "./interface/IMiningLP.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

// 统一合约 - 合并Panel、Master、Factory、DB功能
contract UnifiedContract is Comn {
    using SafeMath for uint256;

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
    
    // 挖矿合约
    address public miningLp;
    address public miningBurn;
    address public miningNode;
    
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
    function getTotalOutputLP() public view returns (uint256 result) {
        result = IMiningLP(miningLp).getTotalOutput();
    }
    
    function getTotalOutputBurn() public view returns (uint256 result) {
        result = IMining(miningBurn).getTotalOutput();
    }
    
    function getCurrentOutputLP(address account) public view returns (uint256 result) {
        result = (account != miningLp ? IMiningLP(miningLp).earned(account) : 0);
    }
    
    function getCurrentOutputNode(address account) public view returns (uint256 result) {
        result = (account != miningNode ? IMining(miningNode).earned(account) : 0);
    }
    
    function getCurrentOutputBurn(address account) public view returns (uint256 result) {
        result = (account != miningBurn ? IMining(miningBurn).earned(account) : 0);
    }
    
    function recCurrentOutputLP(address account) public isCaller returns (uint256 result) {
        result = IMiningLP(miningLp).getReward(account);
    }
    
    function recCurrentOutputNode(address account) public isCaller returns (uint256 result) {
        result = IMining(miningNode).getReward(account);
    }
    
    function recCurrentOutputBurn(address account) public isCaller returns (uint256 result) {
        result = IMining(miningBurn).getReward(account);
    }
    
    function updOutput(uint cakePoolAmount) public isCaller {
        IMiningLP(miningLp).updateOutput(cakePoolAmount);
        IMining(miningBurn).updateOutput(cakePoolAmount);
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
        addLiquidity(caller, rewardToken.mul(10), amountBnb);
        internalUpdateMerit(caller, amountBnb, 1);
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
    function addLiquidity(address caller, uint amountBnb) external payable returns (bool) {
        require(amountBnb > 0, "The amountIn must be greater than 0");
        AbsERC20(wbnb).deposit{value: amountBnb}();
        AbsERC20(wbnb).transfer(address(this), amountBnb);
        this.addLP(caller, amountBnb);
        internalUpdateBalanceCake(msg.sender, cakePair);
        internalUpdateMiningOutput(msg.sender, cakePair);
        return true;
    }
    
    function removeLiquidity(address caller, uint amountIn, address token) external {
        this.removeLP(caller, amountIn);
        internalUpdateBalanceCake(token, cakePair);
        internalUpdateMiningOutput(token, cakePair);
    }
    
    function sellToken(address caller, uint amountIn) external {
        AbsERC20(msg.sender).transfer(address(this), amountIn);
        this.sellToken(caller, amountIn);
        internalUpdateBalanceCake(msg.sender, cakePair);
        internalUpdateMiningOutput(msg.sender, cakePair);
    }
    
    function transferBefore(address from, address to, uint256 amount) external isCaller returns(uint result) {
        uint direction = 3;
        if(from == cakePair) direction = 1;
        else if(to == cakePair) direction = 2;
        else direction = 3;
        
        if(direction == 1) {
            require(block.number > sellLastBlock[msg.sender] + 3, 'Block Cooling');
            result = buyBefore(from, to, amount);
        } else if(direction == 2) {
            require(block.number > sellLastBlock[msg.sender] + 3, 'Block Cooling');
            result = sellBefore(from, to, amount);
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
            buyAfter(from, to, amount, amountBefore);
            sellLastBlock[msg.sender] = block.number;
        } else if(direction == 2) {
            sellAfter(from, to, amount, amountBefore);
            sellLastBlock[msg.sender] = block.number;
        } else if(direction == 3) {
            transAfter(from, to, amount, amountBefore);
        }
    }

    /*---------------------------------------------------Tools功能集成-----------------------------------------------------------*/
    function updateBalanceCake(address token, address target) external isCaller {
        internalUpdateBalanceCake(token, target);
    }
    
    function updateBalanceUser(address token, address target) external isCaller {
        internalUpdateBalanceUser(token, target);
    }
    
    function updateMiningOutput(address token, address target) external isCaller {
        internalUpdateMiningOutput(token, target);
    }
    
    function updateMerit(address target, uint amountIn, uint action) external isCaller {
        internalUpdateMerit(target, amountIn, action);
    }
    
    /*---------------------------------------------------内部函数-----------------------------------------------------------*/
    function internalUpdateBalanceCake(address token, address target) private {
        if(getCurrentOutputBurn(target) > 0){
            miningBurn(token, target, recCurrentOutputBurn(target));
            updCheck(target);
        }
    }
    
    function internalUpdateBalanceUser(address token, address target) private {
        if(getCurrentOutputLP(target) > 0){
            miningMint(token, target, recCurrentOutputLP(target));
        }
        if(getCurrentOutputNode(target) > 0){
            recCurrentOutputNode(target);
        }
    }
    
    function internalUpdateMiningOutput(address token, address target) private {
        uint balanceTarget = AbsERC20(token).getBalance(target);
        uint balancePush = getCurrentOutputBurn(target);
        if(balanceTarget >= balancePush){
            updOutput(balanceTarget.sub(balancePush));
        } else {
            updOutput(balanceTarget);
        }
    }
    
    function internalUpdateMerit(address target, uint amountIn, uint action) private {
        if(action == 1){ // 添加LP
            uint amountBuyBefore = getBuyAmount(target);
            setBuyAmount(target, amountBuyBefore.add(amountIn));
            internalUpdateNode(target);
            for(uint count = 3; count > 0; count--){
                address inviter = getInviter(target);
                if(inviter != address(0)){
                    setTeamAmount(inviter, getTeamAmount(inviter).add(amountIn));
                    internalUpdateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        } else if(action == 2){ // 移除LP
            uint amountBuyBefore = getBuyAmount(target);
            uint amountBuyCurrent = amountBuyBefore >= amountIn ? amountBuyBefore.sub(amountIn) : 0;
            setBuyAmount(target, amountBuyCurrent);
            internalUpdateNode(target);
            for(uint count = 3; count > 0; count--){
                address inviter = getInviter(target);
                if(inviter != address(0)){
                    uint amountTeamBefore = getTeamAmount(inviter);
                    uint amountTeamCurrent = amountTeamBefore >= amountIn ? amountTeamBefore.sub(amountIn) : 0;
                    setTeamAmount(inviter, amountTeamCurrent);
                    internalUpdateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        }
    }
    
    function internalUpdateNode(address target) private {
        uint amountTeam = getTeamAmount(target);
        uint amountUser = getBuyAmount(target);
        uint amountStake = IMining(miningNode).getStakeUser(target);
        if(amountTeam >= joinNodeTeamAmountLimit && amountUser >= joinNodeUserAmountLimit){
            if(amountStake > 0){ // 已经在节点池里
                if(amountUser > amountStake){ // 追加
                    IMining(miningNode).stake(target, amountUser.sub(amountStake));
                } else if(amountUser < amountStake){ // 减少
                    IMining(miningNode).withdraw(target, amountStake.sub(amountUser));
                }
            } else { // 还没在节点池里
                IMining(miningNode).stake(target, amountUser);
            }
        } else {
            if(amountStake > 0){ IMining(miningNode).withdraw(target, amountStake); } // 移除节点池
        }
    }
    function addLiquidity(address spender, uint amountToken, uint amountBnb) private {
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
                IMining(partnerContract).updateOutput(rewardTotal);
            } else {
                AbsERC20(token).burn(rewardTotal);
            }
        }
    }
    
    function rewardNode(address spender, uint amountIn, uint action, address token) private returns(uint rewardTotal) {
        rewardTotal = amountIn.mul(rewardAttrNode[action][1]).div(rewardAttrNode[action][2]);
        if(rewardTotal > 0) {
            if(address(0) != nodeContract) {
                AbsERC20(token).transfer(nodeContract, rewardTotal);
                IMining(nodeContract).updateOutput(rewardTotal);
            } else {
                AbsERC20(token).burn(rewardTotal);
            }
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
    

    
    function buyBefore(address from, address to, uint amount) private returns(uint amountBefore) {
        // 简化买入前逻辑
    }
    
    function buyAfter(address from, address to, uint amount, uint amountBefore) private {
        // 简化买入后逻辑
    }
    
    function sellBefore(address from, address to, uint amount) private returns(uint amountUsdt) {
        // 简化卖出前逻辑
    }
    
    function sellAfter(address from, address to, uint amount, uint amountUsdt) private {
        // 简化卖出后逻辑
    }
    
    function transBefore(address from, address to, uint amount) private returns(uint amountCoin) {
        if(inviterMap[from] != address(0) || inviterMap[to] != address(0)) {
            setBind(from, to);
        }
        showNotice(from);
        internalUpdateBalanceUser(msg.sender, from);
    }
    
    function transAfter(address from, address to, uint amount, uint amountCoin) private {
        // 简化转账后逻辑
    }
    

    
    function showNotice(address from) private {
        address inviter = inviterMap[from];
        uint[] memory noticeArray = new uint[](7);
        noticeArray[0] = buyAmount[from];
        noticeArray[1] = teamAmount[from];
        noticeArray[2] = miningLp != address(0) ? IMiningLP(miningLp).getStakeUser(from) : 0;
        noticeArray[3] = miningNode != address(0) ? IMining(miningNode).getStakeUser(from) : 0;
        noticeArray[4] = 0; // 移除合伙权重功能
        noticeArray[5] = miningLp != address(0) ? IMiningLP(miningLp).getQuotaUser(from) : 0;
        noticeArray[6] = miningLp != address(0) ? IMiningLP(miningLp).getExtractUser(from).add(IMiningLP(miningLp).earned(from)) : 0;
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
    
    function setMiningContract(address _miningLp, address _miningBurn, address _miningNode) external onlyOwner {
        miningLp = _miningLp;
        miningBurn = _miningBurn;
        miningNode = _miningNode;
    }
    
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
    receive() external payable {}
}