// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPanel} from "./interface/IPanel.sol";
import {ISlippage} from "./interface/ISlippage.sol";

contract Token is ERC20,Ownable{
    uint8 public _decimals;

    receive () external payable {
        payable(panel).transfer(msg.value);
        IPanel(panel).addLiquidity(msg.sender,msg.value);
    }

    constructor() ERC20("Brother", "BROO") Ownable(msg.sender){
        _decimals = decimals();
        _mint(msg.sender, 100000000 * (10**uint256(_decimals)));
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 balance = super.balanceOf(account);
        if(panel != address(0) && account != address(0) && account != cakePair){
            return balance + IPanel(panel).getBalanceFactory(account);
        } else {
            return balance;
        }
    }

    function burn(uint256 value) external { _burn(_msgSender(),value); }
    function getBalance(address account) public view returns (uint balance) { balance = super.balanceOf(account); }
    function miningMint(address target,uint256 value) external { if(_msgSender() == panel) { _mint(target,value); } }
    function miningBurn(address target,uint256 value) external { if(_msgSender() == panel) { _burn(target,value); } }

    /*---------------------------------------------------交易-----------------------------------------------------------*/
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if(from == cakePair || to == cakePair){
            bool fromRost = (panel == address(0) ? true : IPanel(panel).getRostSwap(from));
            bool toRost = (panel == address(0) ? true : IPanel(panel).getRostSwap(to));
            bool swapFlag = (panel == address(0) ? false : IPanel(panel).getSwapFlag(address(this)));
            if(swapFlag){
                require(!fromRost && !toRost,"BRO: Transaction Limit");
            } else {
                require(fromRost || toRost,"BRO: Transaction Close");
            }
        }
        _spendAllowance(from, _msgSender(), value);
        _transferChild(from, to, value);
        if(to == address(this)){ _update(address(this),panel,value); IPanel(panel).sellToken(from, value); }
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if(_msgSender() == cakePair || to == cakePair){
            bool fromRost = (panel == address(0) ? true : IPanel(panel).getRostSwap(_msgSender()));
            bool toRost = (panel == address(0) ? true : IPanel(panel).getRostSwap(to));
            bool swapFlag = (panel == address(0) ? false : IPanel(panel).getSwapFlag(address(this)));
            if(swapFlag){
                require(!fromRost && !toRost,"BRO: Transaction Limit");
            } else {
                require(fromRost || toRost,"BRO: Transaction Close");
            }
        }
        _transferChild(_msgSender(), to, value);
        if(to == address(this)){ _update(address(this),panel,value); IPanel(panel).sellToken(_msgSender(), value); }
        return true;
    }

    function _transferChild(address from, address to, uint256 amount) private {
        bool fromRost = IPanel(panel).getRostPanel(from);
        bool toRost   = IPanel(panel).getRostPanel(to);
        uint amountBefore = (!fromRost && !toRost) ? _before(from, to, amount) : 0;
        if(slippage != address(0) && amount > 0){
            uint256 slippageAmount = ISlippage(slippage).slippage(from,to,amount);
            require(slippageAmount < amount,"BRO: Abnormal sliding point");
            if(slippageAmount > 0){
                _transfer(from, to, amount - slippageAmount);
                _transfer(from, slippage, slippageAmount);
                ISlippage(slippage).grant(from,to,amount);
            } else {
                _transfer(from, to, amount);
            }
        } else {
            _transfer(from, to, amount);
        }
        if(!fromRost && !toRost) { _after(from,to,amount,amountBefore); }
    }

    function _before(address from, address to, uint256 amount) private returns(uint amountBefore){
        if(panel != address(0) && amount > 0){ amountBefore = IPanel(panel).transferBefore(from,to,amount); }
    }

    function _after(address from, address to, uint256 amount,uint amountBefore) private{
        if(panel != address(0) && amount > 0){ IPanel(panel).transferAfter(from,to,amount,amountBefore); }
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address public cakePair;                        // Pancake底池地址
    function setConfig(address _cakePair) public onlyOwner { cakePair = _cakePair; }

    address public slippage;
    address public panel;
    function setExternalContract(address _slippage,address _panel) public onlyOwner {
        slippage = _slippage;
        panel = _panel;
    }
}
