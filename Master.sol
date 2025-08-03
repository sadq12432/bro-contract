// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
import {IDB} from "./interface/IDB.sol";
import {IMining} from "./interface/IMining.sol";
import {IMaster} from "./interface/IMaster.sol";
import {ITools} from "./interface/ITools.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

contract Master is Comn,IMaster {
    using SafeMath for uint256;

    /*---------------------------------------------------动作-----------------------------------------------------------*/
    function addLP(address caller,uint amountBnb) external isCaller nonReentrant {
        uint min = IDB(dbContract).getSwapLimitMin(tokenContract,0);
        uint max = IDB(dbContract).getSwapLimitMax(tokenContract,0);
        require(amountBnb >= min && amountBnb <= max, "Master: AddLP transaction limit");
        uint swapAmountWbnb = amountBnb.mul(45).div(100);               // 45%的WBNB先进行交易获得TOKEN
        AbsERC20(wbnb).transfer(cakeV2SwapContract,swapAmountWbnb);
        (uint amountTokenSwap,uint amountTokenSlippage) = ICakeV2Swap(cakeV2SwapContract).swapUsdtToToken(swapAmountWbnb,address(this),wbnbToTokenPath,tokenPair,tokenSlippageContract);
        uint rewardToken = amountTokenSlippage.mul(10).div(45);         // 10%的Token  | 奖励
        uint lpToken = amountTokenSlippage.sub(rewardToken);            // 35%的Token  | 加LP
        uint lpWbnb = amountBnb.mul(35).div(100);                       // 35%的WBNB   | 加LP
        uint ecologyWbnb = amountBnb.sub(swapAmountWbnb).sub(lpWbnb);   // 20%的WBNB   | 生态

        reward(caller,ecologyWbnb,rewardToken,1);                       // 分配奖励
        addLiquidity(caller,rewardToken.mul(10),amountBnb);             // 添加LP
        ITools(toolsContract).updateMerit(caller,amountBnb,1);
    }

    function removeLP(address caller,uint amountIn) external isCaller nonReentrant {
        uint min = IDB(dbContract).getSwapLimitMin(tokenContract,1);
        uint max = IDB(dbContract).getSwapLimitMax(tokenContract,1);
        require(amountIn >= min && amountIn <= max, "Master: RemoveLP transaction limit");
        removeLiquidity(caller,amountIn);
        ITools(toolsContract).updateMerit(caller,IDB(dbContract).getBuyAmount(caller),2);
    }

    function sellToken(address caller,uint amountIn) external isCaller nonReentrant {
        uint min = IDB(dbContract).getSwapLimitMin(tokenContract,2);
        uint max = IDB(dbContract).getSwapLimitMax(tokenContract,2);
        require(amountIn >= min && amountIn <= max, "Master: SellToken transaction limit");
        uint swapAmountToken = amountIn.mul(90).div(100);         // 90%的TOKEN先进行交易获得WBNB
        AbsERC20(tokenContract).transfer(cakeV2SwapContract,swapAmountToken);
        (uint amountUsdtSwap,uint amountUsdtSlippage) = ICakeV2Swap(cakeV2SwapContract).swapTokenToUsdt(swapAmountToken,address(this),tokenToWbnbPath,tokenPair,tokenSlippageContract);
        uint rewardToken = amountIn.sub(swapAmountToken);         // 10%的Token | 奖励

        reward(caller,0,rewardToken,2);                           // 分配奖励
        launchBNB(caller,amountUsdtSlippage);                     // 发射BNB
    }

    function transferToken(address from,address to,uint amountIn) external isCaller nonReentrant{
        if(amountIn > 0){ reward(from,0,amountIn,3); }            // 10%的Token | 奖励
    }

    /*---------------------------------------------------交易-----------------------------------------------------------*/
    /*
     * @desc 奖励分配
     * @param spender 发起人
     * @param amountInCoin 需要分配的Coin数量
     * @param amountInToken 需要分配的Token数量
     * @param action 动作: 1加LP, 2售卖
     */
    function reward(address spender,uint amountInCoin,uint amountInToken,uint action) private returns(uint rewardTotalCoin,uint rewardTotalToken){
        if(action == 1){ // 加LP
            rewardTotalToken = rewardTotalToken + rewardDirect(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardIndirect(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardPartner(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardNode(spender,amountInToken,action,tokenContract);
            rewardTotalCoin = rewardTotalCoin + rewardFund(spender,amountInCoin,action,wbnb);
        } else
        if(action == 2){ // 售卖
            rewardTotalToken = rewardTotalToken + rewardDirect(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardIndirect(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardPartner(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardNode(spender,amountInToken,action,tokenContract);
            rewardTotalToken = rewardTotalToken + rewardFund(spender,amountInToken,action,tokenContract);
        } else
        if(action == 3){} // 转账
    }

    function addLiquidity(address spender,uint amountToken,uint amountBnb) private{
        address directer = IDB(dbContract).getInviter(spender);            // 直推人
        if(directer == address(0)){ _status = _NOT_ENTERED; revert("Master: Not Inviter"); }

        uint balanceToken = AbsERC20(tokenContract).balanceOf(address(this));
        uint balanceWbnb = AbsERC20(wbnb).balanceOf(address(this));
        if(balanceToken > 0 && balanceWbnb > 0){
            AbsERC20(tokenContract).approve(cakeV2Router,balanceToken);
            AbsERC20(wbnb).approve(cakeV2Router,balanceWbnb);
            (uint amountA, uint amountB, uint liquidity) = IPancakeRouterV2(cakeV2Router).addLiquidity(tokenContract,wbnb,balanceToken,balanceWbnb,0,0,address(this),block.timestamp);
            AbsERC20(tokenLpContract).give(spender,liquidity,amountToken,amountBnb);

            balanceToken = AbsERC20(tokenContract).balanceOf(address(this));
            if(balanceToken > 0){ AbsERC20(tokenContract).burn(balanceToken); }
        }
    }

    function removeLiquidity(address spender,uint amount) private{
        AbsERC20(tokenPair).approve(cakeV2Router,amount);
        (uint amountToken, uint amountWbnb) = IPancakeRouterV2(cakeV2Router).removeLiquidity(tokenContract,wbnb,amount,1,1,address(this),block.timestamp);
        uint burnAmountToken = amountToken.div(2);                                                    // 50% X11 燃烧
        uint ecologyAmountToken = amountToken.sub(burnAmountToken);                                   // 50% X11 生态池

        AbsERC20(tokenContract).burn(burnAmountToken);
        AbsERC20(tokenContract).transfer(fundEcologyTokenAddress,ecologyAmountToken);
        launchBNB(spender,amountWbnb);                                                                // 100% BNB 返还
    }

    function launchBNB(address spender,uint amountIn) private{
        AbsERC20(wbnb).withdraw(amountIn);
        (bool sent, bytes memory data) = spender.call{value: amountIn}("");
        require(sent, "Failed to send Ether");
    }

    /*---------------------------------------------------奖励-----------------------------------------------------------*/
    // 直推奖励
    function rewardDirect(address spender,uint amountIn,uint action,address token) private returns(uint rewardTotal){
        rewardTotal = amountIn.mul(rewardAttrDirect[action][1]).div(rewardAttrDirect[action][2]);        // 奖励总金额
        if(rewardTotal > 0){ // 有直推奖励
            address directer = IDB(dbContract).getInviter(spender);        // 直推人
            if(address(0) != directer && IDB(dbContract).getBuyAmount(directer) > 0){ // 有直推人 && 当前持有LP
                AbsERC20(token).transfer(directer,rewardTotal);
            } else { // 无直推人
                AbsERC20(token).burn(rewardTotal);
            }
        }
    }

    // 间推奖励
    function rewardIndirect(address spender,uint amountIn,uint action,address token) private returns(uint rewardTotal){
        rewardTotal = amountIn.mul(rewardAttrIndirect[action][1]).div(rewardAttrIndirect[action][2]);     // 奖励总金额
        if(rewardTotal > 0){ // 有间推奖励
            address directer = IDB(dbContract).getInviter(spender);              // 直推人
            uint rewardPay = 0;                                                  // 已奖励金额
            if(address(0) != directer){ // 有直推人
                uint count = rewardAttrIndirect[action][0];                      // 奖励次数
                uint rewardEvery = rewardTotal.div(count);                       // 每次奖励金额
                for(count; count > 0; count--){
                    address indirecter = IDB(dbContract).getInviter(directer);   // 间推人
                    if(address(0) != indirecter){ // 有间推人
                        if(IDB(dbContract).getBuyAmount(indirecter) > 0){        // 当前持有LP
                            AbsERC20(token).transfer(indirecter,rewardEvery);
                            rewardPay += rewardEvery;                            // 已奖励金额
                        }
                        directer = indirecter;
                    } else { break; } // 无间推人
                }
            }
            if(rewardTotal.sub(rewardPay) > 0){
                AbsERC20(token).burn(rewardTotal.sub(rewardPay));
            }
        }
    }

    // 合伙人
    function rewardPartner(address spender,uint amountIn,uint action,address token) private returns(uint rewardTotal){
        rewardTotal = amountIn.mul(rewardAttrPartner[action][1]).div(rewardAttrPartner[action][2]);        // 奖励总金额
        if(rewardTotal > 0){ // 有合伙人奖励
            if(address(0) != partnerContract){ // 有合伙人
                AbsERC20(token).transfer(partnerContract,rewardTotal);
                IMining(partnerContract).updateOutput(rewardTotal);
            } else { // 无合伙人
                AbsERC20(token).burn(rewardTotal);
            }
        }
    }

    // 节点池
    function rewardNode(address spender,uint amountIn,uint action,address token) private returns(uint rewardTotal){
        rewardTotal = amountIn.mul(rewardAttrNode[action][1]).div(rewardAttrNode[action][2]);        // 奖励总金额
        if(rewardTotal > 0){ // 有节点奖励
            if(address(0) != nodeContract){ // 有节点池
                AbsERC20(token).transfer(nodeContract,rewardTotal);
                IMining(nodeContract).updateOutput(rewardTotal);
            } else { // 无节点池
                AbsERC20(token).burn(rewardTotal);
            }
        }
    }

    // 基金
    function rewardFund(address spender,uint amountIn,uint action,address token) private returns(uint rewardTotal){
        rewardTotal = amountIn.mul(rewardAttrEcology[action][1]).div(rewardAttrEcology[action][2]);        // 奖励总金额
        if(rewardTotal > 0){ // 有生态奖励
            if(wbnb == token){
                if(fundEcologyBnbAddress != address(0)){
                    uint amountCurrent = rewardTotal.mul(fundEcologyScale[0]).div(fundEcologyScale[1]);
                    if(amountCurrent > 0){ launchBNB(fundEcologyBnbAddress,amountCurrent);}
                }
                if(fundMarketBnbAddress != address(0)){
                    uint amountCurrent = rewardTotal.mul(fundMarketScale[0]).div(fundMarketScale[1]);
                    if(amountCurrent > 0){ launchBNB(fundMarketBnbAddress,amountCurrent); }
                }
                if(fundManageBnbAddress != address(0)){
                    uint amountCurrent = rewardTotal.mul(fundManageScale[0]).div(fundManageScale[1]);
                    if(amountCurrent > 0){ launchBNB(fundManageBnbAddress,amountCurrent); }
                }
            } else {
                uint amountPay = 0; // 已发放金额
                if(fundEcologyTokenAddress != address(0)){
                    uint amountCurrent = rewardTotal.mul(fundEcologyScale[0]).div(fundEcologyScale[1]);
                    if(amountCurrent > 0){ AbsERC20(token).transfer(fundEcologyTokenAddress,amountCurrent); amountPay += amountCurrent; }
                }
                if(fundMarketTokenAddress != address(0)){
                    uint amountCurrent = rewardTotal.mul(fundMarketScale[0]).div(fundMarketScale[1]);
                    if(amountCurrent > 0){ AbsERC20(token).transfer(fundMarketTokenAddress,amountCurrent); amountPay += amountCurrent; }
                }
                if(fundManageTokenAddress != address(0)){
                    uint amountCurrent = rewardTotal.mul(fundManageScale[0]).div(fundManageScale[1]);
                    if(amountCurrent > 0){ AbsERC20(token).transfer(fundManageTokenAddress,amountCurrent); amountPay += amountCurrent; }
                }
                if(rewardTotal.sub(amountPay) > 0){ // 未发放完的
                    AbsERC20(token).burn(rewardTotal.sub(amountPay));
                }
            }
        }
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address private dbContract;                                              // [设置]  数据库合约
    address private cakeV2SwapContract;                                      // [设置]  CakeV2合约
    address private tokenLpContract;                                         // [设置]  TokenLP合约
    address private partnerContract;                                         // [设置]  合伙人合约
    address private nodeContract;                                            // [设置]  节点合约
    address private toolsContract;                                           // [设置]  工具合约
    function setExternalContract(address _dbContract,address _cakeV2SwapContract,address _tokenLpContract,address _partnerContract,address _nodeContract,address _toolsContract) public onlyOwner {
        dbContract = _dbContract;
        cakeV2SwapContract = _cakeV2SwapContract;
        tokenLpContract = _tokenLpContract;
        partnerContract = _partnerContract;
        nodeContract = _nodeContract;
        toolsContract = _toolsContract;
    }

    address private tokenContract;                                           // [设置]  代币合约
    address[] private tokenToWbnbPath;                                       // [设置]  代币队路径
    address[] private wbnbToTokenPath;                                       // [设置]  代币队路径
    address private tokenPair;                                               // [设置]  代币Pair
    address private tokenSlippageContract;                                   // [设置]  代币滑点合约
    function setCoinContract(address _tokenContract,address _tokenPair,address _tokenSlippageContract) public onlyOwner {
        tokenContract = _tokenContract;
        tokenToWbnbPath = [_tokenContract,wbnb];
        wbnbToTokenPath = [wbnb,_tokenContract];
        tokenPair = _tokenPair;
        tokenSlippageContract = _tokenSlippageContract;
    }

    mapping(uint => uint[]) private rewardAttrDirect;                        // [设置]  直推奖励属性[key:动作,value:属性(Index:0次数,1分子,2分母)]
    mapping(uint => uint[]) private rewardAttrIndirect;                      // [设置]  间推奖励属性[key:动作,value:属性(Index:0次数,1分子,2分母)]
    mapping(uint => uint[]) private rewardAttrPartner;                       // [设置]  合伙人励属性[key:动作,value:属性(Index:0次数,1分子,2分母)]
    mapping(uint => uint[]) private rewardAttrNode;                          // [设置]  节点池励属性[key:动作,value:属性(Index:0次数,1分子,2分母)]
    mapping(uint => uint[]) private rewardAttrEcology;                       // [设置]  生态基金属性[key:动作,value:属性(Index:0次数,1分子,2分母)]
    function setAttr(uint action,uint[] memory _rewardAttrDirect,uint[] memory _rewardAttrIndirect,uint[] memory _rewardAttrPartner,uint[] memory _rewardAttrNode,uint[] memory _rewardAttrEcology) public onlyOwner {
        rewardAttrDirect[action] = _rewardAttrDirect;
        rewardAttrIndirect[action] = _rewardAttrIndirect;
        rewardAttrPartner[action] = _rewardAttrPartner;
        rewardAttrNode[action] = _rewardAttrNode;
        rewardAttrEcology[action] = _rewardAttrEcology;
    }

    address private fundEcologyBnbAddress;                                    // [设置]  生态基金接收BNB地址
    address private fundMarketBnbAddress;                                     // [设置]  市值基金接收BNB地址
    address private fundManageBnbAddress;                                     // [设置]  管理基金接收BNB地址
    address private fundEcologyTokenAddress;                                  // [设置]  生态基金接收TOKEN地址
    address private fundMarketTokenAddress;                                   // [设置]  市值基金接收TOKEN地址
    address private fundManageTokenAddress;                                   // [设置]  管理基金接收TOKEN地址
    uint[] private fundEcologyScale;                                          // [设置]  接收比例
    uint[] private fundMarketScale;                                           // [设置]  接收比例
    uint[] private fundManageScale;                                           // [设置]  接收比例
    function setFund(address _fundEcologyBnbAddress,address _fundMarketBnbAddress,address _fundManageBnbAddress,address _fundEcologyTokenAddress,address _fundMarketTokenAddress,address _fundManageTokenAddress,uint[] memory _scaleEcology,uint[] memory _scaleMarket,uint[] memory _scaleManage) public onlyOwner {
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
}
