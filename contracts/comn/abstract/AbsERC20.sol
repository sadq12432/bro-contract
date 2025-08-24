pragma solidity ^ 0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract AbsERC20 is IERC20{
    function mint(address account, uint256 value) external virtual;
    function give(address account, uint256 value, uint256 amountToken, uint256 amountBnb) external virtual;
    function burn(uint256 value) external virtual;
    function miningMint(address account, uint256 value) external virtual;
    function miningBurn(address account, uint256 value) external virtual;
    function deposit() external virtual payable;
    function withdraw(uint wad) external virtual;
    function sync() external virtual;
    function getBalance(address account) external view virtual returns (uint balance);
}
