// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {ISlippage} from "./interface/ISlippage.sol";
import {IPanel} from "./interface/IPanel.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

contract Slippage is Comn,ISlippage {
    using SafeMath for uint256;

    function direction(address from, address to) external virtual view returns(uint256){
        if(buyAction[from].total.length > 0){   
            return 1; // 购买动作 
        } else 
        if(sellAction[to].total.length > 0){    
            return 2; // 售卖动作
        } else {                                
            return 3; // 转账动作
        }
    }
    
    function slippage(address from, address to, uint256 amount) external virtual view returns(uint256){
        bool fromWhite = IPanel(panel).getRostSlippage(from);
        bool toWhite = IPanel(panel).getRostSlippage(to);
        if(fromWhite || toWhite){return 0;}     // 滑点白名单
        ScalePair memory scalePair;
        if(buyAction[from].total.length > 0){   // 用户购买动作 
            scalePair = buyAction[from];
        } else 
        if(sellAction[to].total.length > 0){    // 用户售卖动作
            scalePair = sellAction[to];
        } else 
        if(transferAction.total.length > 0){    // 用户转账动作
            scalePair = transferAction;
        }
        if (scalePair.total.length <= 0){ return 0;}                        // 没有滑点
        return amount.mul(scalePair.total[0]).div(scalePair.total[1]);      // 滑点金额 
    }

    function grant(address from, address to, uint256 amountTotal) external virtual isCaller returns(bool){
        bool fromWhite = IPanel(panel).getRostSlippage(from);
        bool toWhite = IPanel(panel).getRostSlippage(to);
        if(fromWhite || toWhite){return true;}     // 滑点白名单
        address spender;
        ScalePair memory scalePair;
        if(buyAction[from].total.length > 0){   // 用户购买动作 
            scalePair = buyAction[from];
            spender = to;
        } else
        if(sellAction[to].total.length > 0){    // 用户售卖动作
            scalePair = sellAction[to];
            spender = from;
        } else
        if(transferAction.total.length > 0){    // 用户转账动作
            scalePair = transferAction;
            spender = from;
        }
        execute(from,to,amountTotal.mul(scalePair.total[0]).div(scalePair.total[1]));         // 总滑金额
        return true;
    }

    /*-------------------------------------------------- 工具 ----------------------------------------------------------*/
    function execute(address from,address to,uint totalSlippage) private{
        AbsERC20(token).transfer(panel,totalSlippage);
        IPanel(panel).transferToken(token,from,to,totalSlippage);
    }
    
    /*---------------------------------------------------初始-----------------------------------------------------------*/
    mapping(address => ScalePair) private buyAction;              // [设置]  购买交易滑点
    mapping(address => ScalePair) private sellAction;             // [设置]  出售交易滑点
    ScalePair private transferAction;                             // [设置]  转账交易滑点
    address private token;                                        // [设置]  代币合约
    address private panel;                                        // [设置]  面板合约
    uint16[] total;                                               // 总滑比例 [分子:[0],分母:[1]] 例:[500,10000] 即 5%
    struct ScalePair { uint16[] total; }                          // 总滑比例 [分子:[0],分母:[1]] 例:[500,10000] 即 5%
    
    function setActionBuy(address _current,uint16[] memory _total) external onlyOwner { buyAction[_current] = ScalePair(_total); }
    function setActionSell(address _current,uint16[] memory _total) external onlyOwner { sellAction[_current] = ScalePair(_total); }
    function setActionTransfer(uint16[] memory _total) external onlyOwner { transferAction = ScalePair(_total); }
    function setExternalContract(address _token,address _panel) external onlyOwner { token = _token; panel = _panel; }
}
