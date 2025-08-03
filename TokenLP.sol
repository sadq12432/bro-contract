// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPanel} from "./interface/IPanel.sol";
import {IMiningLP} from "./interface/IMiningLP.sol";

contract TokenLP is ERC20,Ownable{
    uint8 public _decimals;

    mapping(address => bool) private callerMap;
    modifier isCaller(){
        require(callerMap[msg.sender] || msg.sender == owner(),"BRO-LP: No call permission");
        _;
    }

    function setCaller(address _address,bool _bool) external onlyOwner(){ callerMap[_address] = _bool; }
    function outTransfer(address contractAddress,address targetAddress,uint amountToWei) public isCaller{
        ERC20(contractAddress).transfer(targetAddress,amountToWei);
    }

    constructor() ERC20("Brother LPs", "BRO-LP") Ownable(msg.sender){
        _decimals = decimals();
    }

    function give(address account, uint256 value, uint256 amountToken, uint256 amountBnb) external isCaller {
        _mint(account,value);
        IMiningLP(miningLp).stake(account,amountToken,amountBnb);
    }

    function burn(address account, uint256 value) private {
        _burn(account,value);
        IMiningLP(miningLp).withdraw(account,value);
        IPanel(panel).removeLiquidity(account,value,token);
    }

    /*---------------------------------------------------交易-----------------------------------------------------------*/

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if(to == token || to == address(0)){
            require(value >= super.balanceOf(from),"BRO-LP: Indivisible");
            _spendAllowance(from, _msgSender(), value);
            burn(from,value);
        } else {
            revert("BRO-LP: Not Transfer");
        }
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if(to == token || to == address(0)){
            require(value >= super.balanceOf(_msgSender()),"BRO-LP: Indivisible");
            burn(_msgSender(),value);
        } else {
            revert("BRO-LP: Not Transfer");
        }
        return true;
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address public token;
    address public panel;
    address public miningLp;
    function setExternalContract(address _token,address _panel,address _miningLp) public onlyOwner {
        token = _token;
        panel = _panel;
        miningLp = _miningLp;
    }
}
