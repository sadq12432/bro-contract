pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMaster} from "./interface/IMaster.sol";

contract Token is  ERC20,Ownable{
    uint8 public _decimals;

        receive () external payable {
        payable(master).transfer(msg.value);
        IMaster(master).addLiquidity(msg.sender,msg.value);
    }

     constructor() ERC20("Brother", "BROO") Ownable(msg.sender){
        _decimals = decimals();
        _mint(msg.sender, 100000000 * (10**uint256(_decimals)));
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 balance = super.balanceOf(account);
        if(master != address(0) && account != address(0) && account != cakePair){
            return balance + IMaster(master).getMiningLPReward(account) + IMaster(master).getMiningNodeReward(account);
        } else {
            return balance;
        }
    }

    function burn(uint256 value) external { _burn(_msgSender(),value); }
    function getBalance(address account) public view returns (uint balance) { balance = super.balanceOf(account); }
    function miningMint(address target,uint256 value) external { if(_msgSender() == master) { _mint(target,value); } }
    function miningBurn(address target,uint256 value) external { 
        if(_msgSender() == master) { 
            if(value > 0) {
                uint256 currentTotalSupply = totalSupply();
                uint256 minTotalSupply = 21000000 *  (10**uint256(_decimals));
                
                if (currentTotalSupply > minTotalSupply) {
                    uint256 maxBurnAmount = currentTotalSupply - minTotalSupply;
                    uint256 actualBurnAmount = value > maxBurnAmount ? maxBurnAmount : value;
                    
                    if (actualBurnAmount > 0) {
                        _burn(target, actualBurnAmount);
                    }
                }
            }
        } 
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _transferChild(from, to, value);
        if(to == address(this)){ _update(address(this),master,value); IMaster(master).sellToken(from, value); }
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        _transferChild(_msgSender(), to, value);
        if(to == address(this)){ _update(address(this),master,value); IMaster(master).sellToken(_msgSender(), value); }
        return true;
    }

    function _transferChild(address from, address to, uint256 amount) private {
        uint amountBefore = _before(from, to, amount);
        
        if(amount > 0 && (from == cakePair || to == cakePair)){
            require(msg.sender == address(this) || callWhitelist[msg.sender] || callWhitelist[from] || callWhitelist[to], "not allowed swap");
            
            uint256 slippageAmount = amount * 10 / 100;
            if(slippageAmount > 0&&to == cakePair){
                _transfer(from, to, amount - slippageAmount);
                _transfer(from, master, slippageAmount);
                IMaster(master).transferToken(from, to, slippageAmount);
            } else {
                _transfer(from, to, amount);
            }
        } else {
            _transfer(from, to, amount);
        }
        _after(from,to,amount,amountBefore);
    }

    function _before(address from, address to, uint256 amount) private returns(uint amountBefore){
        if(master != address(0) && amount > 0){ amountBefore = IMaster(master).transferBefore(from,to,amount); }
    }

    function _after(address from, address to, uint256 amount,uint amountBefore) private{
        if(master != address(0) && amount > 0){ IMaster(master).transferAfter(from,to,amount,amountBefore); }
    }

    address public cakePair;
    mapping(address => bool) public callWhitelist;
    
    function setCallWhitelist(address _address, bool _status) public onlyOwner {
        callWhitelist[_address] = _status;
    }
    function setConfig(address _cakePair) public onlyOwner { cakePair = _cakePair; }
  
    address payable public master;
    function setExternalContract(address _unifiedContract) public onlyOwner {
        master = payable(_unifiedContract);
        callWhitelist[_unifiedContract] = true;
    }
}
