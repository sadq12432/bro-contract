// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {IPancakePairV2} from "./comn/interface/IPancakePairV2.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import {IDB} from "./interface/IDB.sol";
import {ITools} from "./interface/ITools.sol";
import {IMining} from "./interface/IMining.sol";
import {IFactory} from "./interface/IFactory.sol";
import {IPanel} from "./interface/IPanel.sol";
import "./comn/Comn.sol";

contract Tools is Comn,ITools {
    using SafeMath for uint256;

    function updateBalanceCake(address token,address target) external isCaller {
        if(IFactory(factory).getCurrentOutputBurn(target) > 0){
            IPanel(panel).miningBurn(token,target,IFactory(factory).recCurrentOutputBurn(target));
            IFactory(factory).updCheck(target);
        }
    }

    function updateBalanceUser(address token,address target) external isCaller {
        if(IFactory(factory).getCurrentOutputLP(target) > 0){
            IPanel(panel).miningMint(token,target,IFactory(factory).recCurrentOutputLP(target));
        }
        if(IFactory(factory).getCurrentOutputPartner(target) > 0){
            IFactory(factory).recCurrentOutputPartner(target);
        }
        if(IFactory(factory).getCurrentOutputNode(target) > 0){
            IFactory(factory).recCurrentOutputNode(target);
        }
    }

    function updateMiningOutput(address token,address target) external isCaller {
        uint balanceTarget = AbsERC20(token).getBalance(target);
        uint balancePush = IFactory(factory).getCurrentOutputBurn(target);
        if(balanceTarget >= balancePush){
            IFactory(factory).updOutput(balanceTarget-balancePush);
        } else {
            IFactory(factory).updOutput(balanceTarget);
        }
    }

    // 更新业绩
    function updateMerit(address target,uint amountIn,uint action) external isCaller {
        if(action == 1){ // 添加LP
            uint amountBuyBefore = IDB(dbContract).getBuyAmount(target);
            IDB(dbContract).setBuyAmount(target,amountBuyBefore.add(amountIn));
            updateNode(target);
            for(uint count = 3; count > 0; count--){
                address inviter = IDB(dbContract).getInviter(target);
                if(inviter != address(0)){
                    IDB(dbContract).setTeamAmount(inviter,IDB(dbContract).getTeamAmount(inviter).add(amountIn));
                    updatePartner(inviter);
                    updateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        } else
        if(action == 2){ // 移除LP
            uint amountBuyBefore = IDB(dbContract).getBuyAmount(target);
            uint amountBuyCurrent = amountBuyBefore >= amountIn ? amountBuyBefore.sub(amountIn) : 0 ;
            IDB(dbContract).setBuyAmount(target,amountBuyCurrent);
            updateNode(target);
            for(uint count = 3; count > 0; count--){
                address inviter = IDB(dbContract).getInviter(target);
                if(inviter != address(0)){
                    uint amountTeamBefore = IDB(dbContract).getTeamAmount(inviter);
                    uint amountTeamCurrent = amountTeamBefore >= amountIn ? amountTeamBefore.sub(amountIn) : 0 ;
                    IDB(dbContract).setTeamAmount(inviter,amountTeamCurrent);
                    updatePartner(inviter);
                    updateNode(inviter);
                    target = inviter;
                } else { break; }
            }
        }
    }
    /*---------------------------------------------------内部-----------------------------------------------------------*/
    function updatePartner(address target) private isCaller { // 更新合伙人
        uint amountTeam = IDB(dbContract).getTeamAmount(target);                    // 团队实时业绩
        uint amountUser = IDB(dbContract).getBuyAmount(target);                     // 个人报单业绩
        uint amountStake = IMining(miningPartnerContract).getStakeUser(target);     // 个人当前质押
        if(amountTeam >= joinPartnerTeamAmountLimit && amountUser >= joinPartnerUserAmountLimit){
            if(amountStake > 0){ // 已经在合伙人池里
                if(amountUser > amountStake){ // 追加
                    IMining(miningPartnerContract).stake(target,amountUser.sub(amountStake));
                } else
                if(amountUser < amountStake){ // 减少
                    IMining(miningPartnerContract).withdraw(target,amountStake.sub(amountUser));
                }
            } else { // 还没在合伙人池里
                IMining(miningPartnerContract).stake(target,amountUser);
            }
        } else {
            if(amountStake > 0){ IMining(miningPartnerContract).withdraw(target,amountStake); } // 移除合伙人池
        }
    }

    function updateNode(address target) private isCaller { // 更新节点
        uint amountTeam = IDB(dbContract).getTeamAmount(target);                 // 团队实时业绩
        uint amountUser = IDB(dbContract).getBuyAmount(target);                  // 个人报单业绩
        uint amountStake = IMining(miningNodeContract).getStakeUser(target);     // 个人当前质押
        if(amountTeam >= joinNodeTeamAmountLimit && amountUser >= joinNodeUserAmountLimit){
            if(amountStake > 0){ // 已经在节点池里
                if(amountUser > amountStake){ // 追加
                    IMining(miningNodeContract).stake(target,amountUser.sub(amountStake));
                } else
                if(amountUser < amountStake){ // 减少
                    IMining(miningNodeContract).withdraw(target,amountStake.sub(amountUser));
                }
            } else { // 还没在节点池里
                IMining(miningNodeContract).stake(target,amountUser);
            }
        } else {
            if(amountStake > 0){ IMining(miningNodeContract).withdraw(target,amountStake); } // 移除节点池
        }
    }


    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    uint private joinPartnerTeamAmountLimit;                                 //[设置]  加入合伙人实时团队业绩限额
    uint private joinPartnerUserAmountLimit;                                 //[设置]  加入合伙人实时自己业绩限额
    uint private joinNodeTeamAmountLimit;                                    //[设置]  加入节点实时团队业绩限额
    uint private joinNodeUserAmountLimit;                                    //[设置]  加入节点实时自己业绩限额
    function setConfig(uint _joinPartnerTeamAmountLimit,uint _joinPartnerUserAmountLimit,uint _joinNodeTeamAmountLimit,uint _joinNodeUserAmountLimit) public onlyOwner {
        joinPartnerTeamAmountLimit = _joinPartnerTeamAmountLimit;
        joinPartnerUserAmountLimit = _joinPartnerUserAmountLimit;
        joinNodeTeamAmountLimit = _joinNodeTeamAmountLimit;
        joinNodeUserAmountLimit = _joinNodeUserAmountLimit;
    }

    address private dbContract;                                              //[设置]  数据库合约
    address public panel;                                                    //[设置]  面板合约
    address public factory;                                                  //[设置]  工厂合约
    address private miningPartnerContract;                                   //[设置]  合伙人合约
    address private miningNodeContract;                                      //[设置]  节点合约
    function setExternalContract(address _dbContract,address _panel,address _factory,address _miningPartnerContract,address _miningNodeContract) public onlyOwner {
        dbContract = _dbContract;
        panel = _panel;
        factory = _factory;
        miningPartnerContract = _miningPartnerContract;
        miningNodeContract = _miningNodeContract;
    }
}
