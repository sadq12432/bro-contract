// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
import {MiningLPLib} from "./comn/library/MiningLPLib.sol";
import {MiningNodeLib} from "./comn/library/MiningNodeLib.sol";
import {SafeMath} from "./comn/library/SafeMath.sol";
import "./comn/Comn.sol";
import {IMaster} from "./interface/IMaster.sol";

interface ITokenLP {
    function give(address account, uint256 value, uint256 amountToken, uint256 amountBnb) external;
}

contract Master is Comn ,IMaster{
    using SafeMath for uint256;
    using MiningLPLib for MiningLPLib.MiningLPData;
    using MiningNodeLib for MiningNodeLib.MiningNodeData;
    using MiningNodeLib for MiningNodeLib.TeamPerformanceData;

    event BindInviter(address indexed member, address indexed inviter);
    event DebugInfo(string message, uint256 value);
    event AddLiquidityDebug(address indexed caller, uint256 amountBnb, address msgSender, address tokenContractAddr);
    event NodeThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event AddLPDetails(address indexed caller, uint256 amountTokenSlippage, uint256 rewardToken, uint256 ecologyWbnb);
    event MiningRewardInfo(address indexed target, uint256 lpReward, uint256 nodeReward);
    event BurnMiningReward(uint256 burnReward);

    mapping(address => address) private inviterMap;
    mapping(address => mapping(address => bool)) private bindMap;
    
    address private tokenContract;
    address private tokenLpContract;

    address public cakePair;
    address[] private tokenToWbnbPath;
    address[] private wbnbToTokenPath;
    
    MiningLPLib.MiningLPData private miningLPData;
    MiningNodeLib.MiningNodeData private miningNodeData;
    MiningNodeLib.TeamPerformanceData private teamPerformanceData;
    
    uint256 private currentNodeIndex;
    
    address[] public ecoAddresses;
    mapping(address => bool) public isEcoAddress;
    uint256 private currentEcoIndex;
    
    uint256 public nodeThreshold = 10 ether;
    uint256 public personalThreshold = 1 ether;
    
    constructor() {
        miningLPData.initialize();
    }
    
    function getInviter(address caller) external view returns (address inviter) {
        inviter = inviterMap[caller];
    }
    
    function isInviter(address caller) external view returns (bool flag) {
        inviterMap[caller] == address(0) ? flag = false : flag = true;
    }
    
    
    function importSingle(address _member, address _inviter) external onlyOwner returns (bool) {
        require(_member != address(0) && _inviter != address(0), "Invalid address");
        inviterMap[_member] = _inviter;
        return true;
    }
    
    function importMulti(address[] memory _memberArray, address[] memory _inviterArray) external onlyOwner returns (bool) {
        require(_memberArray.length != 0 && _memberArray.length == _inviterArray.length, "Invalid arrays");
        for(uint i = 0; i < _memberArray.length; i++) {
            inviterMap[_memberArray[i]] = _inviterArray[i];
        }
        return true;
    }
    

    function addNode(address nodeAddress, uint256 teamPerformance, uint256 personalPerformance) external onlyOwner returns (bool) {
        require(nodeAddress != address(0), "Invalid node address");
        require(teamPerformance > 0 || personalPerformance > 0, "Performance must be greater than 0");
        
        if (teamPerformance > 0) {
            teamPerformanceData.setTeamAmount(nodeAddress, teamPerformance);
        }
        
        if (personalPerformance > 0) {
            teamPerformanceData.setPersonalAmount(nodeAddress, personalPerformance);
        }
        
        teamPerformanceData.checkAndAddToNodePool(nodeAddress, nodeThreshold, personalThreshold);
        
        return true;
    }
    

    function addNodesBatch(address[] calldata nodeAddresses, uint256[] calldata teamPerformances, uint256[] calldata personalPerformances) external onlyOwner returns (bool) {
        require(nodeAddresses.length > 0, "Empty node addresses array");
        require(nodeAddresses.length == teamPerformances.length, "Arrays length mismatch");
        require(nodeAddresses.length == personalPerformances.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < nodeAddresses.length; i++) {
            address nodeAddress = nodeAddresses[i];
            uint256 teamPerformance = teamPerformances[i];
            uint256 personalPerformance = personalPerformances[i];
            
            require(nodeAddress != address(0), "Invalid node address");
            require(teamPerformance > 0 || personalPerformance > 0, "Performance must be greater than 0");
            
            if (teamPerformance > 0) {
                teamPerformanceData.setTeamAmount(nodeAddress, teamPerformance);
            }
            
            if (personalPerformance > 0) {
                teamPerformanceData.setPersonalAmount(nodeAddress, personalPerformance);
            }
            
            teamPerformanceData.checkAndAddToNodePool(nodeAddress, nodeThreshold, personalThreshold);
        }
        
        return true;
    }




  
    function getMiningLPOutput() external view returns (uint256 result) {
        result = miningLPData.getTotalSupply();
    }
    


    function getMiningLPReward(address account) external view returns (uint256 result) {
        result = miningLPData.earned(account);
        
    }
    
  
    function earned(address account) external view returns (uint256) {
        return miningLPData.earned(account);
    }
    
  
    function getCurrentOutputNode(address account) external view returns (uint256 result) {
        result = miningNodeData.earned(account);
    }


    function getMiningNodeReward(address account) external view returns (uint256 result) {
        result = miningNodeData.earned(account);
    }

        function rewardDirectReferrer(address userAddress, uint256 amount)internal returns (bool success) {
        require(userAddress != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");
        
        address inviter = inviterMap[userAddress];
        
        uint256 contractBalance = AbsERC20(tokenContract).balanceOf(address(this));
        
        if (inviter == address(0)) {
            if (contractBalance >= amount) {
                rewardEcoAddress(amount,2);

            } else if (contractBalance > 0) {
                rewardEcoAddress(contractBalance,2);
            }
        } else {
            if (contractBalance >= amount) {
                AbsERC20(tokenContract).transfer(inviter,amount);

            } else if (contractBalance > 0) {
                AbsERC20(tokenContract).transfer(inviter,contractBalance);

            }
        }
        
        return true;
    }
     
    

    function updCheck(address cakePairAddr) internal {

        AbsERC20(cakePairAddr).sync();
    }
    

    function miningMint(address token, address target, uint amount)internal {
        if(amount > 0) {
            AbsERC20(token).miningMint(target, amount); 
        }
    }
    

    function miningBurn(address token, address target, uint amount) internal {
        if(amount > 0) {
            AbsERC20(token).miningBurn(target, amount);  
        }
    }

    ICakeV2Swap private cakeV2SwapContract;
    
  
    function setCakeV2SwapContract(address _cakeV2SwapContract) external onlyOwner {
        require(_cakeV2SwapContract != address(0), "Invalid contract address");
        cakeV2SwapContract = ICakeV2Swap(_cakeV2SwapContract);
        
    }
    
        function swapTokenToWBnb(uint amountToken, address receiveAddress, address[] memory path, address pair, address slippage) internal returns (uint amountWbnbSwap, uint amountWbnbSlippage) {
        require(address(cakeV2SwapContract) != address(0), "CakeV2Swap contract not set");
        AbsERC20(tokenContract).transfer(address(cakeV2SwapContract),amountToken);

        return cakeV2SwapContract.swapTokenToWBnb(amountToken, receiveAddress, path, pair, slippage);
    }
        function swapWbnbToToken(uint amountWbnb, address receiveAddress, address[] memory path, address pair, address slippage) internal returns (uint amountTokenSwap, uint amountTokenSlippage) {
        AbsERC20(wbnb).transfer(address(cakeV2SwapContract),amountWbnb);
        require(address(cakeV2SwapContract) != address(0), "CakeV2Swap contract not set");
        return cakeV2SwapContract.swapWbnbToToken(amountWbnb, receiveAddress, path, pair, slippage);
    }



    function addLiquidity(address caller, uint amountBnb) external  nonReentrant  isCaller  returns (bool) {
        require(amountBnb > 0, "The amountIn must be greater than 0");
        
        emit AddLiquidityDebug(caller, amountBnb, msg.sender, tokenContract);
        
        AbsERC20(wbnb).deposit{value: amountBnb}();
        addLP(caller, amountBnb);  
        updateBalanceCake();
        updateTeamAmount(caller, amountBnb);
        emit MiningRewardInfo(caller, 0, 0);
        updateBalanceUser(tokenContract, caller);

        return true;
    }
    
    function addLiquidityInternal(address caller, uint amountBnb) internal {
        require(amountBnb > 0, "The amountIn must be greater than 0");
        
        addLP(caller, amountBnb);
        updateTeamAmount(caller, amountBnb);
    }
    
    function addLP(address caller, uint amountBnb) internal{
        require(amountBnb > 0, "Amount must be greater than 0");

        uint swapAmountWbnb = amountBnb.mul(45).div(100);
        (, uint amountTokenSlippage) = swapWbnbToToken(swapAmountWbnb, address(this), wbnbToTokenPath, cakePair, address(0));

        uint stakeToken = amountTokenSlippage.mul(100).div(45);
        uint ecologyWbnb = amountBnb.mul(20).div(100);
        reward(caller, ecologyWbnb, 0, 1);
        
        emit AddLPDetails(caller, amountTokenSlippage, stakeToken, ecologyWbnb);
        
         miningLPData.stake(caller, stakeToken);

        _addLiquidityInternal(caller, 0, amountBnb);

    }
    
    function _addLiquidityInternal(address caller, uint rewardToken, uint amountBnb) internal {
        uint balanceToken = AbsERC20(tokenContract).balanceOf(address(this));
        uint balanceWbnb = AbsERC20(wbnb).balanceOf(address(this));

        if(balanceToken > 0 && balanceWbnb > 0) {
            _approveAndAddCakeV2Liquidity(balanceToken, balanceWbnb);            
            uint remainingToken = AbsERC20(tokenContract).balanceOf(address(this));
            if(remainingToken > 0) {
                AbsERC20(tokenContract).burn(remainingToken);
            }
        }
    }
    
    function _approveAndAddCakeV2Liquidity(uint balanceToken, uint balanceWbnb) internal returns (uint liquidity) {
          AbsERC20(tokenContract).approve(cakeV2Router,balanceToken);
            AbsERC20(wbnb).approve(cakeV2Router,balanceWbnb);
            (uint amountA, uint amountB, uint liquidityAmount) = IPancakeRouterV2(cakeV2Router).addLiquidity(tokenContract,wbnb,balanceToken,balanceWbnb,0,0,address(this),block.timestamp);
        
        return liquidityAmount;
    }
    
    function sellToken(address caller, uint amountIn) external  isCaller   {
        require(amountIn > 0, "Amount must be greater than 0");
        
        uint swapAmountToken = amountIn;
        (uint amountWbnbSwap, uint amountWbnbSlippage) = swapTokenToWBnb(swapAmountToken, address(this), tokenToWbnbPath, cakePair, address(0));
        
        uint lpToken = amountWbnbSlippage.mul(2).div(10);
        launchBNB(caller, amountWbnbSlippage-lpToken);
        launchBNB(address(this),lpToken);

        this.addLiquidity(caller, lpToken);

    }
    
    function transferToken(address from, address to, uint amountIn) external   isCaller {
        if(amountIn > 0) {
            reward(from, 0, amountIn, 3);
        }
    }

  
   
    
    function transferBefore(address from, address to, uint256 amount) external  isCaller  returns(uint result) {
        uint direction = 3;
        if(from == cakePair) direction = 1;
        else if(to == cakePair) direction = 2;
        else direction = 3;
      
        if(direction == 3) {
            result = transBefore(from, to, amount);
        }
    }
    
    function transferAfter(address from, address to, uint256 amount, uint amountBefore) external  isCaller {

        
    }

    function getMiningLPTotalSupply() external view returns (uint256) {
        return miningLPData.totalSupply;
    }
    
    function getMiningLPUserBalance(address account) external view returns (uint256) {
        return miningLPData.getUserBalance(account);
    }
    
    function getMiningNodeUserBalance(address account) external view returns (uint256) {
        return miningNodeData.earned(account);
    }

    function getNodePoolCount() external view returns (uint256) {
        return teamPerformanceData.getNodePoolSize();
    }
    
    function nodePoolAddresses(uint256 index) external view returns (address) {
        address[] memory addresses = teamPerformanceData.getNodePoolAddresses();
        require(index < addresses.length, "Index out of bounds");
        return addresses[index];
    }
    
    function getNodePoolAddresses() external view returns (address[] memory) {
        return teamPerformanceData.getNodePoolAddresses();
    }
    
    function getLastBurnClaimTime() external view returns (uint256) {
        return miningLPData.getLastBurnClaimTime();
    }
    
    function getDailyBurnRate() external view returns (uint256) {
        return miningLPData.getDailyBurnRate();
    }
    
    function getPendingBurnAmount() external view returns (uint256) {
        return miningLPData.getPendingBurnAmount();
    }
    
    function geteBurnAmount() external view returns (uint256) {
        return miningLPData.calculateBurnAmount();
    }

    function getTeamPerformance(address target) external view returns (uint256) {
        if (target == address(0)) {
            return teamPerformanceData.getTotalTeamPerformance();
        } else {
            return teamPerformanceData.getTeamPerformance(target);
        }
    }

    function getPersonalPerformance(address target) external view returns (uint256) {
        return teamPerformanceData.getPersonalPerformance(target);
    }

    function updateBalanceCake() internal {
        uint balanceTarget = AbsERC20(tokenContract).getBalance(cakePair);
        uint256 burnReward = miningLPData.claimBurnMining();
        
        if(balanceTarget >= burnReward&& balanceTarget>0){
              miningBurn(tokenContract, cakePair, burnReward);
              emit BurnMiningReward(burnReward);


        }else{
             miningBurn(tokenContract, cakePair, balanceTarget);
            emit BurnMiningReward(balanceTarget);


        }
        AbsERC20(cakePair).sync();
        
    }
    
    function updateBalanceUser(address token, address target) internal{
        uint256 lpReward = miningLPData.getReward(target);
        if(lpReward > 0){
            miningMint(token, target, lpReward);
        }
        uint256 nodeReward = miningNodeData.getReward(target);
        if(nodeReward > 0){
            miningMint(token, target, nodeReward);
        }
        
        emit MiningRewardInfo(target, lpReward, nodeReward);
        
    }

    function distributeNodePoolRewards(uint256 totalReward) internal {
        MiningNodeLib.distributeNodePoolRewards(miningNodeData, teamPerformanceData, totalReward);
    }



    function checkAndAddToNodePool(address user) internal {
        if (MiningNodeLib.checkAndAddToNodePool(teamPerformanceData, user, nodeThreshold, personalThreshold)) {
            ITokenLP(tokenLpContract).give(user, 0, 0, 0);
        }
    }
    
    function updateTeamAmount(address user, uint256 amount) internal {
        (uint256 newTotalPerformance, address[] memory newNodeUsers) = MiningNodeLib.updateTeamAmountWithTokenLP(
            teamPerformanceData,
            user,
            amount,
            inviterMap,
            nodeThreshold,
            personalThreshold,
            miningLPData.totalPerformance
        );
        miningLPData.totalPerformance = newTotalPerformance;
        for (uint i = 0; i < newNodeUsers.length; i++) {
            ITokenLP(tokenLpContract).give(newNodeUsers[i], 0, 0, 0);
        }
    }
    
    function internalSetBind(address from, address to) private {
      if(from == address(0)){return;}
        if(from == address(this)){return;}
        if(to == address(0)){return;}
        if(to == address(this)){return;}
        if(from == to){return;}
        if(from == msg.sender){return;}
        if(to == msg.sender){return;}
            if(!bindMap[from][to]){
                bindMap[from][to] = true;
                if(bindMap[to][from]){
                    if(inviterMap[from] != address(0)){return;}
                    if(teamPerformanceData.isInNodePool(from)){return;}
                    inviterMap[from] = to;
                    uint256 fromTeamAmount = teamPerformanceData.getTeamPerformance(from);
                    if(fromTeamAmount > 0) {
                        teamPerformanceData.addTeamPerformance(to, fromTeamAmount);
                        checkAndAddToNodePool(to);
                    }
                    emit BindInviter(from,to);

                }
            
        }
    }

  
    
    function launchBNB(address spender, uint amountIn) private {
        AbsERC20(wbnb).withdraw(amountIn);
        (bool sent, ) = spender.call{value: amountIn}("");
        require(sent, "Failed to send Ether");
    }
    
    function reward(address spender, uint amountInCoin, uint amountInToken, uint action) private returns(uint rewardTotalCoin, uint rewardTotalToken) {
        
        if (action == 1 || action == 2||action == 3) {

         
            
            if (amountInToken > 0) {
                uint directReward = amountInToken.mul(3).div(10);
                uint nodeReward = amountInToken.sub(directReward);
                rewardDirectReferrer(spender, directReward);
                distributeNodePoolRewards(nodeReward);

            }
            if (amountInCoin > 0 && ecoAddresses.length > 0) {
               rewardEcoAddress(amountInCoin,1);
            }
        }
        
        return (0, 0);
    }
    


    
    function transBefore(address from, address to, uint amount) private returns(uint amountCoin) {
        internalSetBind(from, to);
        updateBalanceUser(tokenContract,from);
    }
    
    
    function setContractAddresses(
        address _tokenContract,
        address _tokenLpContract,
        address _cakeV2SwapContract,
        address _cakePair,
        address _wbnb
    ) public onlyOwner {
        tokenContract = _tokenContract;
        tokenLpContract = _tokenLpContract;
        cakeV2SwapContract = ICakeV2Swap(_cakeV2SwapContract);
        cakePair = _cakePair;
        wbnb = _wbnb;
        

        tokenToWbnbPath = [_tokenContract, wbnb];
        wbnbToTokenPath = [wbnb, _tokenContract];
    }
    
 
    function getContractAddresses() external view returns (
        address,
        address,
        address,
        address,
        address
    ) {
        return (
            tokenContract,
            tokenLpContract,
            address(cakeV2SwapContract),
            cakePair,
            wbnb
        );
    }
    
    function addEcoAddress(address _ecoAddress) external onlyOwner {
        require(_ecoAddress != address(0), "Invalid address");
        require(!isEcoAddress[_ecoAddress], "Address already exists");
        
        ecoAddresses.push(_ecoAddress);
        isEcoAddress[_ecoAddress] = true;
    }
    
    function addEcoAddressesBatch(address[] calldata _ecoAddresses) external onlyOwner {
        require(_ecoAddresses.length > 0, "Empty eco addresses array");
        
        for (uint256 i = 0; i < _ecoAddresses.length; i++) {
            address _ecoAddress = _ecoAddresses[i];
            require(_ecoAddress != address(0), "Invalid address");
            require(!isEcoAddress[_ecoAddress], "Address already exists");
            
            ecoAddresses.push(_ecoAddress);
            isEcoAddress[_ecoAddress] = true;
        }
    }
    
    function removeEcoAddress(address _ecoAddress) external onlyOwner {
        require(isEcoAddress[_ecoAddress], "Address not found");
        
        for (uint256 i = 0; i < ecoAddresses.length; i++) {
            if (ecoAddresses[i] == _ecoAddress) {
                ecoAddresses[i] = ecoAddresses[ecoAddresses.length - 1];
                ecoAddresses.pop();
                break;
            }
        }
        
        isEcoAddress[_ecoAddress] = false;
        
        if (currentEcoIndex >= ecoAddresses.length && ecoAddresses.length > 0) {
            currentEcoIndex = 0;
        }
    }
    
    function setNodeThreshold(uint256 _nodeThreshold) external onlyOwner {
        require(_nodeThreshold > 0, "Node threshold must be greater than 0");
        uint256 oldThreshold = nodeThreshold;
        nodeThreshold = _nodeThreshold;
        emit NodeThresholdUpdated(oldThreshold, _nodeThreshold);
    }
    
    function setPersonalThreshold(uint256 _personalThreshold) external onlyOwner {
        require(_personalThreshold > 0, "Personal threshold must be greater than 0");
        personalThreshold = _personalThreshold;
    }
    
    function getNodeThreshold() external view returns (uint256) {
        return nodeThreshold;
    }
    
    function getPersonalThreshold() external view returns (uint256) {
        return personalThreshold;
    }
    
    function rewardEcoAddress(uint256 amount,uint action) internal {
        if(ecoAddresses.length == 0) return;
        currentEcoIndex = (currentEcoIndex + 1) % ecoAddresses.length;

        address rewardAddress = ecoAddresses[currentEcoIndex];
        if(action==1){
            launchBNB(rewardAddress, amount);
        }else{
            AbsERC20(tokenContract).transfer(rewardAddress,amount);
        }
    }
    
    function getEcoAddressCount() external view returns (uint256) {
        return ecoAddresses.length;
    }
    
    function getCurrentEcoAddress() external view returns (address) {
        require(ecoAddresses.length > 0, "No eco addresses available");
        return ecoAddresses[currentEcoIndex];
    }
    
    function setStakingThreshold(uint256 _stakingThreshold) external onlyOwner {
        miningLPData.setStakingThreshold(_stakingThreshold);
    }
    
    function getStakingThreshold() external view returns (uint256) {
        return miningLPData.getStakingThreshold();
    }
    
    function getUserStakingLimit(address account) external view returns (uint256) {
        return miningLPData.getStakingLimit(account);
    }
    
    function getTotalPerformance() external view returns (uint256) {
        return miningLPData.getTotalPerformance();
    }
    
    receive() external payable override {
    }
}