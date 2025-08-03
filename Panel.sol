// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {ISlippage} from "./interface/ISlippage.sol";
import {IDB} from "./interface/IDB.sol";
import {IPanel} from "./interface/IPanel.sol";
import {IMaster} from "./interface/IMaster.sol";
import {IMining} from "./interface/IMining.sol";
import {IMiningLP} from "./interface/IMiningLP.sol";
import {IFactory} from "./interface/IFactory.sol";
import {ITools} from "./interface/ITools.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

// 面板
contract Panel is IPanel,Comn{
    using SafeMath for uint256;

    function getSwapFlag(address _coin) external view virtual returns (bool){ return IDB(dbContract).getSwapFlag(msg.sender); }
    function getRostSlippage(address _target) external view virtual returns (bool){ return IDB(dbContract).getRostSlippage(_target); }
    function getRostSwap(address _target) external view virtual returns (bool){ return IDB(dbContract).getRostSwap(_target); }
    function getRostPanel(address _target) external view virtual returns (bool){ return IDB(dbContract).getRostPanel(_target);}
    function getBalanceFactory(address _target) external view virtual returns (uint amountOut){ amountOut = IFactory(factoryContract).getCurrentOutputLP(_target) + IFactory(factoryContract).getCurrentOutputPartner(_target) + IFactory(factoryContract).getCurrentOutputNode(_target); }

    /*---------------------------------------------------添加LP-----------------------------------------------------------*/
    function addLiquidity(address caller,uint amountBnb) external virtual isCaller payable returns (bool){
        require(amountBnb > 0, "Panel: The amountIn must be greater than 0");
        AbsERC20(wbnb).deposit{value: amountBnb}();
        AbsERC20(wbnb).transfer(masterContract,amountBnb);
        IMaster(masterContract).addLP(caller,amountBnb);
        ITools(toolsContract).updateBalanceCake(msg.sender,cakePair);
        ITools(toolsContract).updateMiningOutput(msg.sender,cakePair);
        return true;
    }

    /*---------------------------------------------------移除LP-----------------------------------------------------------*/
    function removeLiquidity(address caller,uint amountIn,address token) external virtual isCaller {
        IMaster(masterContract).removeLP(caller,amountIn);
        ITools(toolsContract).updateBalanceCake(token,cakePair);
        ITools(toolsContract).updateMiningOutput(token,cakePair);
    }

    /*---------------------------------------------------售卖-----------------------------------------------------------*/
    function sellToken(address caller,uint amountIn) external virtual isCaller {
        AbsERC20(msg.sender).transfer(masterContract,amountIn);
        IMaster(masterContract).sellToken(caller,amountIn); // 卖
        ITools(toolsContract).updateBalanceCake(msg.sender,cakePair);
        ITools(toolsContract).updateMiningOutput(msg.sender,cakePair);
    }

    /*---------------------------------------------------转账-----------------------------------------------------------*/
    function transferToken(address token,address from,address to,uint amountIn) external virtual isCaller returns(uint amountOut){
        AbsERC20(token).transfer(masterContract,amountIn);
        IMaster(masterContract).transferToken(from,to,amountIn);
    }

    function miningMint(address goal,address target,uint256 value) external isCaller { AbsERC20(goal).miningMint(target,value); }
    function miningBurn(address goal,address target,uint256 value) external isCaller { AbsERC20(goal).miningBurn(target,value); }

    /*---------------------------------------------------动作-----------------------------------------------------------*/
    function transferBefore(address from, address to, uint256 amount) external virtual isCaller returns(uint result){
        uint direction = 3; // 方向 1:买 2:卖 3:转账
        direction = ISlippage(slippageContract).direction(from,to);
        if(direction == 1){ // 买
            if(!IDB(dbContract).getRostBuyWait(to)){ require(block.number > IDB(dbContract).getSellLastBlock(msg.sender) + 3,'Panel: Block Cooling'); } // 交易冷却3区块
            result = buyBefore(from,to,amount);
        } else
        if(direction == 2){ // 卖
            if(!IDB(dbContract).getRostBuyWait(from)){ require(block.number > IDB(dbContract).getSellLastBlock(msg.sender) + 3,'Panel: Block Cooling'); } // 交易冷却3区块
            result = sellBefore(from,to,amount);
        } else
        if(direction == 3){ // 转
            result = transBefore(from,to,amount);
        }
    }

    function transferAfter(address from, address to, uint256 amount,uint amountBefore) external virtual isCaller{
        uint direction = 3; // 方向 1:买 2:卖 3:转账
        direction = ISlippage(slippageContract).direction(from,to);
        if(direction == 1){ // 买
            buyAfter(from,to,amount,amountBefore);
            IDB(dbContract).setSellLastBlock(msg.sender,block.number);              // 交易冷却3区块
        } else
        if(direction == 2){ // 卖
            sellAfter(from,to,amount,amountBefore);
            IDB(dbContract).setSellLastBlock(msg.sender,block.number);              // 交易冷却3区块
        } else
        if(direction == 3){ // 转
            transAfter(from,to,amount,amountBefore);
        }
    }

    /*---------------------------------------------------买-----------------------------------------------------------*/
    function buyBefore(address from,address to,uint amount) private returns(uint amountBefore){}
    function buyAfter(address from,address to,uint amount,uint amountBefore) private {}

    /*---------------------------------------------------卖-----------------------------------------------------------*/
    function sellBefore(address from,address to,uint amount) private returns(uint amountUsdt){}
    function sellAfter(address from,address to,uint amount,uint amountUsdt) private {}

    /*---------------------------------------------------转-----------------------------------------------------------*/
    function transBefore(address from,address to,uint amount) private returns(uint amountCoin){
        if(IDB(dbContract).getInviter(from) != address(0) || IDB(dbContract).getInviter(to) != address(0)){ IDB(dbContract).setBind(from,to); }
        showNotice(from);
        ITools(toolsContract).updateBalanceUser(msg.sender,from);
    }
    function transAfter(address from,address to,uint amount,uint amountCoin) private {
        IFactory(factoryContract).recCurrentOutputLock(from,to);
    }

    /*---------------------------------------------------Log-----------------------------------------------------------*/
    function showNotice(address from) private {
        address inviter = IDB(dbContract).getInviter(from);
        uint[] memory noticeArray =  new uint[](7);
        noticeArray[0] = IDB(dbContract).getBuyAmount(from);                                               // 个人参与
        noticeArray[1] = IDB(dbContract).getTeamAmount(from);                                              // 团队业绩 下3代
        noticeArray[2] = IMiningLP(miningLp).getStakeUser(from);                                           // 个人矿池权重
        noticeArray[3] = IMining(miningNode).getStakeUser(from);                                           // 个人节点权重
        noticeArray[4] = IMining(miningPartner).getStakeUser(from);                                        // 个人合伙权重
        noticeArray[5] = IMiningLP(miningLp).getQuotaUser(from);                                           // 当期矿池产出额度
        noticeArray[6] = IMiningLP(miningLp).getExtractUser(from).add(IMiningLP(miningLp).earned(from));   // 当期矿池产出收益
        emit Notice(inviter,noticeArray[0],noticeArray[1],noticeArray[2],noticeArray[3],noticeArray[4],noticeArray[5],noticeArray[6]);
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address public cakePair;                        // Pancake底池地址
    function setConfig(address _cakePair) public onlyOwner { cakePair = _cakePair; }

    address private dbContract;                                              // 数据库合约
    address private cakeV2SwapContract;                                      // CakeV2合约
    address private slippageContract;                                        // 滑点合约
    address private masterContract;                                          // 大师合约
    address private toolsContract;                                           // 工具合约
    address private factoryContract;                                         // 工厂合约
    function setExternalContract(address _dbContract,address _cakeV2SwapContract,address _slippageContract,address _masterContract,address _toolsContract,address _factoryContract) public onlyOwner {
        dbContract = _dbContract;
        cakeV2SwapContract = _cakeV2SwapContract;
        slippageContract = _slippageContract;
        masterContract = _masterContract;
        toolsContract = _toolsContract;
        factoryContract = _factoryContract;
    }

    address private miningLp;                                         // LP合约
    address private miningNode;                                       // 节点合约
    address private miningPartner;                                    // 合伙合约
    function setPoolContract(address _miningLp,address _miningNode,address _miningPartner) public onlyOwner {
        miningLp = _miningLp;
        miningNode = _miningNode;
        miningPartner = _miningPartner;
    }

}
