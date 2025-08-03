// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IDB} from "./interface/IDB.sol";
import {Comn} from "./comn/Comn.sol";

// 数据库合约
contract DB is IDB,Comn{
    /*---------------------------------------------------推荐关系-----------------------------------------------------------*/
    mapping(address => address) private inviterMap;                          // 推荐关系map
    function getInviter(address caller) external view virtual returns (address inviter){
        inviter = inviterMap[caller];
    }
    function isInviter(address caller) external view virtual returns (bool flag){
        inviterMap[caller] == address(0) ? flag = false : flag = true;
    }
    /*---------------------------------------------------绑定关系-----------------------------------------------------------*/
    mapping(address => mapping(address => bool)) private bindMap;            // 绑定关系map
    function setBind(address from,address to) external virtual isCaller {
        if(from == address(0)){return;}
        if(from == address(this)){return;}
        if(to == address(0)){return;}
        if(to == address(this)){return;}
        if(from == to){return;}
        if(from == msg.sender){return;}
        if(to == msg.sender){return;}
        if(inviterMap[from] != address(0) || inviterMap[to] != address(0)){
            if(!bindMap[from][to]){ // from还没有绑定他
                bindMap[from][to] = true;
                if(bindMap[to][from]){
                    if(inviterMap[to] == address(0)){return;}
                    if(inviterMap[from] != address(0)){return;}
                    inviterMap[from] = to;
                    emit BindInviter(from,to);
                }
            }
        }
    }
    /*---------------------------------------------------导入关系-----------------------------------------------------------*/
    function importSingle(address _member,address _inviter) external onlyOwner returns (bool){
        require(_member != address(0),"DB : member Can't be 0");
        require(_inviter != address(0),"DB : member Can't be 0");
        inviterMap[_member] = _inviter;
        return true;
    }
    function importMulti(address[] memory _memberArray,address[] memory _inviterArray) external onlyOwner returns (bool){
        require(_memberArray.length != 0,"DB : Not equal to 0");
        require(_inviterArray.length != 0,"DB : Not equal to 0");
        require(_memberArray.length == _inviterArray.length,"DB : Inconsistent length");
        for(uint i=0;i<_memberArray.length;i++){
            inviterMap[_memberArray[i]] = _inviterArray[i];
        }
        return true;
    }
    /*---------------------------------------------------交易控制-----------------------------------------------------------*/
    mapping(address => bool) private tokenSwap;                             // 交易开关 false:关闭交易,名单为白名单;true:开放交易,名单为黑名单
    function getSwapFlag(address coin) external view virtual returns (bool){ return tokenSwap[coin]; }
    function setSwapFlag(address coin,bool _flag) external virtual onlyOwner { tokenSwap[coin] = _flag; }

    /*---------------------------------------------------交易限额-----------------------------------------------------------*/
    mapping(address => mapping(uint => uint)) private swapLimitMin;         // 交易限额 最小
    function getSwapLimitMin(address coin,uint action) external view virtual returns (uint){ return swapLimitMin[coin][action]; }
    function setSwapLimitMin(address coin,uint action,uint amount) external virtual onlyOwner { swapLimitMin[coin][action] = amount; }

    mapping(address => mapping(uint => uint)) private swapLimitMax;         // 交易限额 最大
    function getSwapLimitMax(address coin,uint action) external view virtual returns (uint){ return swapLimitMax[coin][action]; }
    function setSwapLimitMax(address coin,uint action,uint amount) external virtual onlyOwner { swapLimitMax[coin][action] = amount; }

    /*---------------------------------------------------交易记录-----------------------------------------------------------*/
    mapping(address => uint) private sellLastBlock;                         // 最后一笔卖出区块
    function getSellLastBlock(address coin) external view virtual returns (uint blockNumber){ blockNumber = sellLastBlock[coin]; }
    function setSellLastBlock(address coin,uint blockNumber) external virtual isCaller{ sellLastBlock[coin] = blockNumber; }

    /*---------------------------------------------------交易信息-----------------------------------------------------------*/
    mapping(address => bool) private rostSwap;                             //[设置]  交易白名单
    function getRostSwap(address _target) external view virtual returns (bool){ return rostSwap[_target];}
    function setRostSwap(address _target,bool _flag) external virtual onlyOwner nonReentrant { rostSwap[_target] = _flag; }

    /*---------------------------------------------------转账信息-----------------------------------------------------------*/
    mapping(address => bool) private rostPanel;                            //[设置]  面板白名单
    function getRostPanel(address _target) external view virtual returns (bool){ return rostPanel[_target];}
    function setRostPanel(address _target,bool _flag) external virtual onlyOwner nonReentrant { rostPanel[_target] = _flag; }

    /*---------------------------------------------------滑点信息-----------------------------------------------------------*/
    mapping(address => bool) private rostSlippage;                         //[设置]  滑点白名单
    function getRostSlippage(address _target) external view virtual returns (bool){ return rostSlippage[_target]; }
    function setRostSlippage(address _target,bool _flag) external virtual onlyOwner nonReentrant { rostSlippage[_target] = _flag; }

    /*-------------------------------------------------购买等待白名单-----------------------------------------------------------*/
    mapping(address => bool) private rostBuyWaitMap;                       //[设置]  购买等待白名单
    function getRostBuyWait(address _target) external view virtual returns (bool){ return rostBuyWaitMap[_target];}
    function setRostBuyWait(address _target,bool _flag) external virtual onlyOwner nonReentrant { rostBuyWaitMap[_target] = _flag; }

    /*---------------------------------------------------团队实时业绩-----------------------------------------------------------*/
    mapping(address => uint) private teamAmount;
    function getTeamAmount(address target) external view virtual returns (uint amountOut){ amountOut = teamAmount[target]; }
    function setTeamAmount(address target,uint amountIn) external virtual isCaller{ teamAmount[target] = amountIn; }

    /*---------------------------------------------------自己实时业绩-----------------------------------------------------------*/
    mapping(address => uint) private buyAmount;
    function getBuyAmount(address target) external view virtual returns (uint amountOut){ amountOut = buyAmount[target]; }
    function setBuyAmount(address target,uint amountIn) external virtual isCaller{ buyAmount[target] = amountIn; }


}
