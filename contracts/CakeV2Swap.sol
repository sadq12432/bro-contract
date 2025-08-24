// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import {AbsERC20} from "./comn/abstract/AbsERC20.sol";
import "./comn/Comn.sol";

contract CakeV2Swap is Comn,ICakeV2Swap{
    using SafeMath for uint256;

    function swapTokenToWBnb(uint amountToken,address receiveAddress,address[] memory path,address pair,address slippage) external  isCaller  returns (uint amountWbnbSwap,uint amountWbnbSlippage){
        uint balanceBefore = AbsERC20(path[1]).balanceOf(receiveAddress);
        uint amountOutMin = getInToOut(amountToken,path,pair).mul(minScale[0]).div(minScale[1]);
        swapInToOutFee(amountToken,amountOutMin,path,receiveAddress);
        uint balanceAfter = AbsERC20(path[1]).balanceOf(receiveAddress);
        amountWbnbSwap = balanceAfter - balanceBefore;    
        amountWbnbSlippage=  amountWbnbSwap;
    }

    function swapWbnbToToken(uint amountWbnb,address receiveAddress,address[] memory path,address pair,address slippage) external   isCaller  returns (uint amountTokenSwap,uint amountTokenSlippage){
        uint amountOutMin = getInToOut(amountWbnb,path,pair).mul(minScale[0]).div(minScale[1]);
        amountTokenSwap = swapInToOut(amountWbnb,amountOutMin,path,receiveAddress);
        amountTokenSlippage = amountTokenSwap ;
    }

    function swapInToOut(uint amountIn,uint amountOutMin,address[] memory path,address receiveAddress) private  isCaller returns (uint amountOut) {
        (uint[] memory amounts) = IPancakeRouterV2(cakeV2Router).swapExactTokensForTokens(amountIn,amountOutMin,path,receiveAddress,block.timestamp + 60);
        amountOut = amounts[1];
    }

    function swapTokenToWbnbFee(uint amountToken,address receiveAddress,address[] memory path,address pair,address slippage) external isCaller  returns (uint amountWbnbSwap) {
        uint amountSlippage = amountToken.mul(10).div(100);
        uint amountOutMin = getInToOut(amountToken-amountSlippage,path,pair).mul(minScale[0]).div(minScale[1]);
        uint balanceBefore = AbsERC20(path[1]).balanceOf(receiveAddress);
        swapInToOutFee(amountToken,amountOutMin,path,receiveAddress);
        uint balanceAfter = AbsERC20(path[1]).balanceOf(receiveAddress);
        amountWbnbSwap = balanceAfter - balanceBefore;
    }

    function swapWbnbToTokenFee(uint amountWbnb,address receiveAddress,address[] memory path,address pair) external  isCaller   returns (uint amountTokenSwap) {
        uint amountOutMin = getInToOut(amountWbnb,path,pair).mul(minScale[0]).div(minScale[1]);
        uint balanceBefore = AbsERC20(path[1]).balanceOf(receiveAddress);
        swapInToOutFee(amountWbnb,amountOutMin,path,receiveAddress);
        uint balanceAfter = AbsERC20(path[1]).balanceOf(receiveAddress);
        amountTokenSwap = balanceAfter - balanceBefore;
    }

    function swapInToOutFee(uint amountIn,uint amountOutMin,address[] memory path,address receiveAddress)   private {
        IPancakeRouterV2(cakeV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn,amountOutMin,path,receiveAddress,block.timestamp + 60);
    }

    function getInToOut(uint amountIn,address[] memory path,address poolPair) public view virtual returns (uint amountOut) {
        uint balanceIn = AbsERC20(path[0]).balanceOf(poolPair);
        uint balanceOut = AbsERC20(path[1]).balanceOf(poolPair);
        amountOut = IPancakeRouterV2(cakeV2Router).getAmountOut(amountIn,balanceIn,balanceOut);
    }

    uint[] private minScale = [8000,10000];
    
    function approveWbnbToRouter() external onlyOwner {
        AbsERC20(wbnb).approve(cakeV2Router, approveMax);
    }
    
    function approveTokenToRouter(address token) external onlyOwner {
        AbsERC20(token).approve(cakeV2Router, approveMax);
    }
    
    function addLiquidity(address tokenContract, uint256 balanceToken, uint256 balanceWbnb) external  isCaller  returns (uint256 liquidity) {
        require(AbsERC20(tokenContract).balanceOf(address(this)) >= balanceToken, "Insufficient token balance");
        require(AbsERC20(wbnb).balanceOf(address(this)) >= balanceWbnb, "Insufficient WBNB balance");
        
        (,, liquidity) = IPancakeRouterV2(cakeV2Router).addLiquidity(
            tokenContract, wbnb, balanceToken, balanceWbnb, 0, 0, address(this), block.timestamp + 60
        );
    }

}