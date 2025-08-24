pragma solidity ^ 0.8.24;

import {AbsERC20} from "./abstract/AbsERC20.sol";

abstract contract Comn {
    address internal constant burn = 0x000000000000000000000000000000000000dEaD;
    address internal constant usdt = 0x55d398326f99059fF775485246999027B3197955;
    address internal wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant cakeV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    uint256 internal constant approveMax = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 internal constant slippageRate = 10;
    address private owner;
    mapping(address => bool) private callerMap;
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;
    uint256 internal _status = 1;
    modifier onlyOwner() virtual {
        require(msg.sender == owner,"Comn: The caller is not the creator");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "Comn: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier isCaller() {
        require(callerMap[msg.sender], "Comn: The caller is not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        _status = _NOT_ENTERED;
    }

    function getOwner() public view returns (address) { return owner; }
    function getCaller(address target) public view returns (bool) { return callerMap[target]; }
    function renounceOwnership() external virtual onlyOwner { owner = address(0); }
    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Comn: new owner is the zero address");
        require(newOwner != owner, "Comn: new owner is the same as current owner");
        owner = newOwner;
    }
    function setCaller(address _address,bool _bool) external onlyOwner(){ callerMap[_address] = _bool; }

    function outTransfer(address contractAddress,address targetAddress,uint amountToWei) public virtual isCaller{
        AbsERC20(contractAddress).transfer(targetAddress,amountToWei);
    }
    function outTransferFrom(address contractAddress,address fromAddress,address targetAddress,uint amountToWei) public isCaller{
        AbsERC20(contractAddress).transferFrom(fromAddress,targetAddress,amountToWei);
    }
    fallback () external payable {}
    receive () external payable virtual {}
    function withdraw() external onlyOwner() { payable(msg.sender).transfer(payable(this).balance);}
}