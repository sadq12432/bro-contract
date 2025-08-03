// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {IFactory} from "./interface/IFactory.sol";
import {IMining} from "./interface/IMining.sol";
import {IMiningLP} from "./interface/IMiningLP.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";

contract Factory is Comn,IFactory {
    using SafeMath for uint256;

    function getTotalOutputLP() public view virtual returns (uint256 result) { result = IMiningLP(miningLp).getTotalOutput(); }
    function getTotalOutputBurn() public view virtual returns (uint256 result) { result = IMining(miningBurn).getTotalOutput(); }

    function getCurrentOutputLP(address account) public view virtual returns (uint256 result) { result = (account != miningLp ? IMiningLP(miningLp).earned(account) : 0); }
    function getCurrentOutputPartner(address account) public view virtual returns (uint256 result) { result = (account != miningPartner ? IMining(miningPartner).earned(account) : 0); }
    function getCurrentOutputNode(address account) public view virtual returns (uint256 result) { result = (account != miningNode ? IMining(miningNode).earned(account) : 0); }
    function getCurrentOutputBurn(address account) public view virtual returns (uint256 result) { result = (account != miningBurn ? IMining(miningBurn).earned(account) : 0); }

    function recCurrentOutputLP(address account) public isCaller virtual returns (uint256 result) { result = IMiningLP(miningLp).getReward(account); }
    function recCurrentOutputPartner(address account) public isCaller virtual returns (uint256 result) { result = IMining(miningPartner).getReward(account); }
    function recCurrentOutputNode(address account) public isCaller virtual returns (uint256 result) { result = IMining(miningNode).getReward(account); }
    function recCurrentOutputBurn(address account) public isCaller virtual returns (uint256 result) {result = IMining(miningBurn).getReward(account);}
    function recCurrentOutputLock(address from,address to) public isCaller virtual returns (uint256 result) {
        if(to == miningLock){ result = IMining(miningLock).getReward(from); }
    }

    function updOutput(uint cakePoolAmount) public isCaller virtual {
        IMiningLP(miningLp).updateOutput(cakePoolAmount);
        IMining(miningBurn).updateOutput(cakePoolAmount);
    }

    function updCheck(address cakePair) public isCaller virtual { AbsERC20(cakePair).sync(); }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address public miningLp;
    address public miningBurn;
    address public miningPartner;
    address public miningNode;
    address public miningLock;
    function setExternalContract(address _miningLp,address _miningBurn,address _miningPartner,address _miningNode,address _miningLock) external onlyOwner {
        miningLp = _miningLp;
        miningBurn = _miningBurn;
        miningPartner = _miningPartner;
        miningNode = _miningNode;
        miningLock = _miningLock;
    }

}
