// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
// 移除ISlippage导入，简化滑点逻辑
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

// 通过调用薄饼完成指定金额交易
contract CakeV2Swap is Comn,ICakeV2Swap{
    using SafeMath for uint256;

    /*---------------------------------------------------精准交易-----------------------------------------------------------*/
    function swapTokenToWBnb(uint amountToken,address receiveAddress,address[] memory path,address pair,address slippage) external virtual isCaller returns (uint amountWbnbSwap,uint amountWbnbSlippage){
        // 简化：直接使用10%滑点
        uint amountSlippage = amountToken.mul(10).div(100);
        uint amountOutMin = getInToOut(amountToken-amountSlippage,path,pair).mul(minScale[0]).div(minScale[1]);       // 预测:使用token,获得Wbnb(结果再打指定折)
        amountWbnbSwap = swapInToOut(amountToken,amountOutMin,path,receiveAddress);                                   // 兑换:使用token,获得Wbnb (这里暂时保留验证,实际到帐WBNB是否会因为滑点而受影响)
        amountWbnbSlippage = amountWbnbSwap;
    }

    function swapWbnbToToken(uint amountWbnb,address receiveAddress,address[] memory path,address pair,address slippage) external virtual isCaller returns (uint amountTokenSwap,uint amountTokenSlippage){
        uint amountOutMin = getInToOut(amountWbnb,path,pair).mul(minScale[0]).div(minScale[1]);        // 预测:使用Wbnb,获得token(结果再打指定折)
        amountTokenSwap = swapInToOut(amountWbnb,amountOutMin,path,receiveAddress);                    // 兑换:使用Wbnb,获得token
        // 简化：直接使用10%滑点
        uint amountSlippage = amountTokenSwap.mul(10).div(100);
        amountTokenSlippage = amountTokenSwap - amountSlippage;
    }

    // 兑换:使用In,获得Out
    function swapInToOut(uint amountIn,uint amountOutMin,address[] memory path,address receiveAddress) private returns (uint amountOut) {
        (uint[] memory amounts) = IPancakeRouterV2(cakeV2Router).swapExactTokensForTokens(amountIn,amountOutMin,path,receiveAddress,block.timestamp + 60);
        amountOut = amounts[1];
    }


    /*---------------------------------------------------扣费交易-----------------------------------------------------------*/
    function swapTokenToWbnbFee(uint amountToken,address receiveAddress,address[] memory path,address pair,address slippage) external virtual isCaller {
        // 简化：直接使用10%滑点
        uint amountSlippage = amountToken.mul(10).div(100);
        uint amountOutMin = getInToOut(amountToken-amountSlippage,path,pair).mul(minScale[0]).div(minScale[1]);       // 预测:使用token,获得Wbnb(结果再打指定折)
        swapInToOutFee(amountToken,amountOutMin,path,receiveAddress);                                                 // 兑换:使用token,获得Wbnb (这里暂时保留验证,实际到帐WBNB是否会因为滑点而受影响)
    }

    function swapWbnbToTokenFee(uint amountWbnb,address receiveAddress,address[] memory path,address pair) external virtual isCaller {
        uint amountOutMin = getInToOut(amountWbnb,path,pair).mul(minScale[0]).div(minScale[1]);        // 预测:使用Wbnb,获得token(结果再打指定折)
        swapInToOutFee(amountWbnb,amountOutMin,path,receiveAddress);                                   // 兑换:使用Wbnb,获得token
    }

    // 兑换:使用In,获得Out，支持转账时扣费
    function swapInToOutFee(uint amountIn,uint amountOutMin,address[] memory path,address receiveAddress) private {
        IPancakeRouterV2(cakeV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn,amountOutMin,path,receiveAddress,block.timestamp + 60);
    }

    /*---------------------------------------------------公共查询-----------------------------------------------------------*/
    // 预测:使用In,获得Out
    function getInToOut(uint amountIn,address[] memory path,address poolPair) public view virtual returns (uint amountOut) {
        uint balanceIn = AbsERC20(path[0]).balanceOf(poolPair);
        uint balanceOut = AbsERC20(path[1]).balanceOf(poolPair);
        amountOut = IPancakeRouterV2(cakeV2Router).getAmountOut(amountIn,balanceIn,balanceOut);
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    uint[] private minScale = [9500,10000];                    // 交易滑点 | 本地
    
    function setConfig(uint[] memory _minScale) public onlyOwner {
        minScale = _minScale;
    }

    function setApproval(address _contract,address spender) public onlyOwner {
        AbsERC20(_contract).approve(spender,approveMax);
    }
}