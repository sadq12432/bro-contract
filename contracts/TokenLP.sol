// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenLP is ERC721,Ownable{
    uint256 private _nextTokenId = 1;
    
    mapping(address => bool) private callerMap;
    modifier isCaller(){
        require(callerMap[msg.sender] || msg.sender == owner(),"BRO-LP: No call permission");
        _;
    }

    function setCaller(address _address,bool _bool) external onlyOwner(){ callerMap[_address] = _bool; }
    function outTransfer(address contractAddress,address targetAddress,uint amountToWei) public isCaller{
        ERC721(contractAddress).transferFrom(address(this), targetAddress, amountToWei);
    }

    constructor() ERC721("Brother LPs", "BRO-LP") Ownable(msg.sender){
        // NFT构造函数
    }

    function give(address account, uint256 value, uint256 amountToken, uint256 amountBnb) external isCaller {
        // 为用户铸造NFT，使用递增的tokenId
        _mint(account, _nextTokenId);
        _nextTokenId++;
    }

  
    /*---------------------------------------------------交易-----------------------------------------------------------*/

    function transferFrom(address from, address to, uint256 tokenId) public override {
        revert("BRO-LP: Transfer not allowed");
    }

    // 重写_update来拦截转账
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        // 只允许铸造（to != address(0) && from == address(0)）和销毁（to == address(0)）
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert("BRO-LP: Transfer not allowed");
        }
        return super._update(to, tokenId, auth);
    }
    
    // // 提供销毁NFT的公共接口
    // function burnNFT(uint256 tokenId) external {
    //     require(ownerOf(tokenId) == _msgSender(), "BRO-LP: Not owner");
    //     burn(tokenId);
    // }


    
    function burn(uint256 tokenId) private {
        _burn(tokenId);
    }
    
    // 获取用户拥有的NFT数量
    function balanceOf(address owner) public view override returns (uint256) {
        return super.balanceOf(owner);
    }
    
    // 获取下一个要铸造的tokenId
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }
    
    // 检查tokenId是否存在
    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
