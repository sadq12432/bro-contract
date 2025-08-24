pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./comn/Comn.sol";

contract TokenLP is ERC721,Comn{
    uint256 private _nextTokenId = 1;
    

    
    function outTransfer(address contractAddress,address targetAddress,uint amountToWei) public override isCaller {
        ERC721(contractAddress).transferFrom(address(this), targetAddress, amountToWei);
    }

    constructor() ERC721("Brother LPs", "BRO-LP"){
    }

    function give(address account, uint256 value, uint256 amountToken, uint256 amountBnb) external  isCaller {
        _mint(account, _nextTokenId);
        _nextTokenId++;
    }
    
  

  

    function transferFrom(address from, address to, uint256 tokenId) public override {
        revert("BRO-LP: Transfer not allowed");
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert("BRO-LP: Transfer not allowed");
        }
        return super._update(to, tokenId, auth);
    }
    
    
    
    function burnToken(uint256 tokenId) private {
        _burn(tokenId);
    }
    
    function balanceOf(address owner) public view override returns (uint256) {
        return super.balanceOf(owner);
    }
    
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }
    
    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
