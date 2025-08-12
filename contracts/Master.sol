// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

// 导入PancakeSwap路由器接口
import {IPancakeRouterV2} from "./comn/interface/IPancakeRouterV2.sol";
// 导入自定义交换合约接口
import {ICakeV2Swap} from "./interface/ICakeV2Swap.sol";
// 导入LP挖矿库
import {MiningLPLib} from "./comn/library/MiningLPLib.sol";
// 导入节点挖矿库
import {MiningNodeLib} from "./comn/library/MiningNodeLib.sol";
// 导入安全数学库
import {SafeMath} from "./comn/library/SafeMath.sol";
// 导入通用合约基类
import "./comn/Comn.sol";

// TokenLP接口
interface ITokenLP {
    function give(address account, uint256 value, uint256 amountToken, uint256 amountBnb) external;
}

/**
 * @title Master
 * @dev 统一合约 - 合并Panel、Master、Factory、DB功能
 * 这是一个综合性的DeFi合约，包含推荐关系管理、挖矿功能、流动性管理等核心功能
 */
contract Master is Comn {
    // 使用SafeMath库进行安全的数学运算
    using SafeMath for uint256;
    // 使用LP挖矿库
    using MiningLPLib for MiningLPLib.MiningLPData;
    // 使用节点挖矿库
    using MiningNodeLib for MiningNodeLib.MiningNodeData;

    /*---------------------------------------------------事件定义-----------------------------------------------------------*/
    
    /**
     * @dev 绑定推荐人事件
     * @param member 被推荐人地址
     * @param inviter 推荐人地址
     */
    event BindInviter(address indexed member, address indexed inviter);
    


    /*---------------------------------------------------数据存储-----------------------------------------------------------*/
    
    // 推荐关系管理
    mapping(address => address) private inviterMap;  // 用户 => 推荐人地址映射
    mapping(address => mapping(address => bool)) private bindMap;  // 双向绑定确认映射
    

    // 交易记录管理
    mapping(address => uint) private sellLastBlock;  // 用户最后卖出区块号，用于冷却限制
    
    /*---------------------------------------------------外部合约地址-----------------------------------------------------------*/
    
    address private cakeV2SwapContract;  // CakeV2交换合约地址
    address private tokenContract;       // 项目代币合约地址
    address private tokenLpContract;     // LP代币合约地址

    address public cakePair;             // Cake交易对地址
    address[] private tokenToWbnbPath;   // 代币到WBNB的交换路径
    address[] private wbnbToTokenPath;   // WBNB到代币的交换路径
    address private tokenPair;           // 代币交易对地址
    
    // 挖矿数据结构实例
    MiningLPLib.MiningLPData private miningLPData;        // LP挖矿数据
    MiningNodeLib.MiningNodeData private miningNodeData;  // 节点挖矿数据
    

    
    // 存储每个用户的团队业绩（包括自己和所有下级的业绩总和）
    mapping(address => uint256) public teamAmount;
    
    // 节点池：存储已加入节点的用户地址
    mapping(address => bool) public nodePool;
    
    // 节点池地址数组，用于轮询
    address[] public nodePoolAddresses;
    
    // 当前轮询索引
    uint256 private currentNodeIndex;
    
    // 生态地址管理
    address[] public ecoAddresses;  // 生态地址数组
    mapping(address => bool) public isEcoAddress;  // 检查地址是否为生态地址
    uint256 private currentEcoIndex;  // 当前生态地址轮询索引
    
    /**
     * @dev 获取用户的推荐人地址
     * @param caller 查询的用户地址
     * @return inviter 推荐人地址，如果没有推荐人则返回零地址
     */
    function getInviter(address caller) external view returns (address inviter) {
        inviter = inviterMap[caller];  // 返回推荐人地址
    }
    
    /**
     * @dev 检查用户是否有推荐人
     * @param caller 查询的用户地址
     * @return flag 如果有推荐人返回true，否则返回false
     */
    function isInviter(address caller) external view returns (bool flag) {
        inviterMap[caller] == address(0) ? flag = false : flag = true;  // 检查推荐人是否存在
    }
    
    /**
     * @dev 设置双向绑定关系，需要双方都确认才能建立推荐关系
     * @param from 被推荐人地址
     * @param to 推荐人地址
     * 只有当双方都确认绑定且满足条件时，才会建立推荐关系
     */
    function setBind(address from, address to) internal {
        // 检查地址有效性，排除无效地址和自引用
        if(from == address(0) || from == address(this) || to == address(0) || to == address(this) || from == to || from == msg.sender || to == msg.sender) return;
        
        // 只有当其中一方已有推荐关系时才能进行绑定
        if(inviterMap[from] != address(0) || inviterMap[to] != address(0)) {
            if(!bindMap[from][to]) {
                bindMap[from][to] = true;  // 设置from到to的绑定确认
                // 检查是否双向确认
                if(bindMap[to][from]) {
                    if(inviterMap[to] == address(0)) return;  // to必须没有推荐人
                    if(inviterMap[from] != address(0)) return;  // from必须已有推荐人
                    inviterMap[from] = to;  // 建立推荐关系
                    emit BindInviter(from, to);  // 触发绑定事件
                }
            }
        }
    }
    
    /**
     * @dev 管理员导入单个推荐关系
     * @param _member 被推荐人地址
     * @param _inviter 推荐人地址
     * @return 操作是否成功
     */
    function importSingle(address _member, address _inviter) external onlyOwner returns (bool) {
        require(_member != address(0) && _inviter != address(0), "Invalid address");
        inviterMap[_member] = _inviter;  // 直接设置推荐关系
        return true;
    }
    
    /**
     * @dev 管理员批量导入推荐关系
     * @param _memberArray 被推荐人地址数组
     * @param _inviterArray 推荐人地址数组
     * @return 操作是否成功
     */
    function importMulti(address[] memory _memberArray, address[] memory _inviterArray) external onlyOwner returns (bool) {
        require(_memberArray.length != 0 && _memberArray.length == _inviterArray.length, "Invalid arrays");
        // 批量设置推荐关系
        for(uint i = 0; i < _memberArray.length; i++) {
            inviterMap[_memberArray[i]] = _inviterArray[i];
        }
        return true;
    }



    /*---------------------------------------------------交易记录-----------------------------------------------------------*/
    /**
     * @dev 获取用户最后卖出区块号
     * @param coin 查询的用户地址
     * @return blockNumber 用户最后一次卖出操作的区块号
     */
    function getSellLastBlock(address coin) external view returns (uint blockNumber) {
        blockNumber = sellLastBlock[coin];  // 返回最后卖出区块号
    }
    
    /**
     * @dev 设置用户最后卖出区块号
     * @param coin 目标用户地址
     * @param blockNumber 要设置的区块号
     * 只有授权调用者可以设置用户的最后卖出区块号，用于冷却限制
     */
    function setSellLastBlock(address coin, uint blockNumber) external isCaller {
        sellLastBlock[coin] = blockNumber;  // 设置最后卖出区块号
    }

    /*---------------------------------------------------挖矿工厂功能-----------------------------------------------------------*/
    /**
     * @dev 获取LP挖矿总产出
     * @return result LP挖矿总供应量
     */
    function getMiningLPOutput() external view returns (uint256 result) {
        result = miningLPData.getTotalSupply();
    }
    

    
    /**
     * @dev 获取用户LP挖矿奖励
     * @param account 用户地址
     * @return result 用户可领取的LP挖矿奖励
     */
    function getMiningLPReward(address account) external view returns (uint256 result) {
        result = miningLPData.earned(account);
    }
    
    /**
     * @dev 获取用户当前节点挖矿产出
     * @param account 用户地址
     * @return result 用户当前节点挖矿收益
     */
    function getCurrentOutputNode(address account) external view returns (uint256 result) {
        result = miningNodeData.earned(account);
    }

    /**
     * @dev 获取用户可领取的节点挖矿奖励
     * @param account 用户地址
     * @return result 用户可领取的节点挖矿奖励
     */
    function getMiningNodeReward(address account) external view returns (uint256 result) {
        result = miningNodeData.earned(account);
    }

    /**
     * @dev 奖励直推函数 - 将指定数量的token从合约转给用户的上级推荐人
     * 如果没有上级推荐人，则燃烧掉这笔奖励
     * 如果合约余额不足，则燃烧掉剩余的数量
     * @param userAddress 用户地址
     * @param amount 奖励数量
     * @return success 是否成功处理
     */
    function rewardDirectReferrer(address userAddress, uint256 amount)internal nonReentrant returns (bool success) {
        require(userAddress != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");
        
        // 获取用户的推荐人地址
        address inviter = inviterMap[userAddress];
        
        // 获取合约当前token余额
        uint256 contractBalance = AbsERC20(tokenContract).balanceOf(address(this));
        
        if (inviter == address(0)) {
            // 如果没有上级推荐人，燃烧掉这笔奖励
            if (contractBalance >= amount) {
                AbsERC20(tokenContract).miningBurn(address(this), amount);
            } else if (contractBalance > 0) {
                // 如果合约余额不足，燃烧掉剩余的数量
                AbsERC20(tokenContract).miningBurn(address(this), contractBalance);
            }
        } else {
            // 有推荐人的情况
            if (contractBalance >= amount) {
                // 合约余额充足，转账给推荐人
                AbsERC20(tokenContract).transfer(inviter,amount);

            } else if (contractBalance > 0) {
                // 合约余额不足，转账剩余数量给推荐人
                AbsERC20(tokenContract).transfer(inviter,contractBalance);

            }
        }
        
        return true;
    }
     
    
/*
     * @dev 更新检查并同步交易对
     * @param cakePairAddr Cake交易对地址
     */
    function updCheck(address cakePairAddr) public isCaller {
        AbsERC20(cakePairAddr).sync();
    }
    
    /**
     * @dev 挖矿铸造代币
     * @param token 代币合约地址
     * @param target 目标用户地址
     * @param amount 铸造数量
     * 为指定用户铸造代币作为挖矿奖励
     */
    function miningMint(address token, address target, uint amount) public isCaller {
        if(amount > 0) {
            AbsERC20(token).miningMint(target, amount);  // 为用户铸造代币
        }
    }
    
    /**
     * @dev 挖矿销毁代币
     * @param token 代币合约地址
     * @param target 目标用户地址
     * @param amount 销毁数量
     * 销毁指定数量的代币，用于通缩机制
     */
    function miningBurn(address token, address target, uint amount) public isCaller {
        if(amount > 0) {
            AbsERC20(token).miningBurn(target, amount);  // 销毁代币
        }
    }

    /*---------------------------------------------------主要业务逻辑-----------------------------------------------------------*/
    /**
     * @dev 添加流动性挖矿
     * @param caller 调用者地址
     * @param amountBnb BNB数量
     * 将BNB按比例分配：45%用于交换代币，35%用于添加流动性，20%用于生态奖励
     */
    function addLP(address caller, uint amountBnb) internal{
        require(amountBnb > 0, "Amount must be greater than 0");  // 检查BNB数量有效性
        
        uint swapAmountWbnb = amountBnb.mul(45).div(100);  // 45%用于交换代币
        AbsERC20(wbnb).transfer(cakeV2SwapContract, swapAmountWbnb);  // 转账到交换合约
        (uint amountTokenSwap, uint amountTokenSlippage) = ICakeV2Swap(cakeV2SwapContract).swapWbnbToToken(swapAmountWbnb, address(this), wbnbToTokenPath, tokenPair, address(0));  // 执行代币交换
        
        uint rewardToken = amountTokenSlippage.mul(10).div(45);  // 计算奖励代币数量
        uint lpToken = amountTokenSlippage.sub(rewardToken);  // 计算LP代币数量
        uint lpWbnb = amountBnb.mul(35).div(100);  // 35%用于添加流动性
        uint ecologyWbnb = amountBnb.sub(swapAmountWbnb).sub(lpWbnb);  // 剩余用于生态奖励
        reward(caller, ecologyWbnb, rewardToken, 1);  // 分发奖励
        
        // 内部添加流动性逻辑（原addLiquidityInternal函数内容）
        uint balanceToken = AbsERC20(tokenContract).balanceOf(address(this));  // 获取合约代币余额
        uint balanceWbnb = AbsERC20(wbnb).balanceOf(address(this));  // 获取合约WBNB余额
        miningLPData.stake(caller, rewardToken.mul(10));

        if(balanceToken > 0 && balanceWbnb > 0) {
            AbsERC20(tokenContract).approve(cakeV2Router, balanceToken);  // 授权代币给路由器
            AbsERC20(wbnb).approve(cakeV2Router, balanceWbnb);  // 授权WBNB给路由器
            // 调用PancakeSwap添加流动性
            (,, uint liquidity) = IPancakeRouterV2(cakeV2Router).addLiquidity(
                tokenContract, wbnb, balanceToken, balanceWbnb, 0, 0, address(this), block.timestamp
            );
            AbsERC20(tokenLpContract).give(caller, liquidity, rewardToken.mul(10), amountBnb);  // 分发LP代币给用户
            miningLPData.stake(caller, rewardToken.mul(10));  // 将代币质押到LP挖矿池
            balanceToken = AbsERC20(tokenContract).balanceOf(address(this));  // 检查剩余代币
            if(balanceToken > 0) {
                 AbsERC20(tokenContract).burn(balanceToken);  // 销毁剩余代币
             }
        }
        
      
       
    }
 
    
    /**
     * @dev 卖出代币
     * @param caller 调用者地址
     * @param amountIn 卖出的代币数量
     * 90%的代币用于交换WBNB，10%用于奖励分配
     */
    function sellToken(address caller, uint amountIn) external isCaller nonReentrant {
        require(amountIn > 0, "Amount must be greater than 0");  // 检查代币数量有效性
        
    

        uint swapAmountToken = amountIn.mul(90).div(100);  // 90%用于交换
        AbsERC20(tokenContract).transfer(cakeV2SwapContract, swapAmountToken);  // 转账到交换合约
        (uint amountWbnbSwap, uint amountWbnbSlippage) = ICakeV2Swap(cakeV2SwapContract).swapTokenToWBnb(swapAmountToken, address(this), tokenToWbnbPath, tokenPair, address(0));  // 执行代币到WBNB的交换
        uint rewardToken = amountIn.sub(swapAmountToken);  // 10%用于奖励
        
        reward(caller, 0, rewardToken, 2);  // 分发奖励
        uint lpToken = amountWbnbSlippage.mul(2).div(10);  // 20%用于添加流动性
        launchBNB(caller, amountWbnbSlippage-lpToken);  // 发送BNB给用户
        AbsERC20(wbnb).withdraw(lpToken);  // 将WBNB提取为bnb

        //将LP代币转账给合约
        this.addLiquidity(caller, lpToken);  // 20%用于添加流动性

    }
    
    /**
     * @dev 代币转账处理
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amountIn 转账数量
     * 处理代币转账时的奖励分配
     */
    function transferToken(address from, address to, uint amountIn) external isCaller nonReentrant {
        if(amountIn > 0) {
            reward(from, 0, amountIn, 3);  // 转账时分发奖励
        }
    }

    /*---------------------------------------------------添加流动性-----------------------------------------------------------*/
    function addLiquidity(address caller, uint amountBnb) external payable nonReentrant returns (bool) {
        require(amountBnb > 0, "The amountIn must be greater than 0");
        AbsERC20(wbnb).deposit{value: amountBnb}();
        AbsERC20(wbnb).transfer(address(this), amountBnb);
        addLP(caller, amountBnb);

        uint256 burnReward = miningLPData.claimBurnMining();
        if(burnReward > 0){
            miningBurn(tokenContract, cakePair,burnReward);
            AbsERC20(cakePair).sync();
        }
        
   
        updateBalanceCake();
                  // 更新团队业绩：递归更新调用者及其上级的团队业绩

        updateTeamAmount(caller, amountBnb);
        
        return true;
    }
   
    
    // 重复的sellToken函数已删除
    
    function transferBefore(address from, address to, uint256 amount) external isCaller returns(uint result) {
        uint direction = 3;
        if(from == cakePair) direction = 1;
        else if(to == cakePair) direction = 2;
        else direction = 3;
        
        if(direction == 1) {
            require(block.number > sellLastBlock[msg.sender] + 3, 'Block Cooling');
            result = 0;
        } else if(direction == 2) {
            require(block.number > sellLastBlock[msg.sender] + 3, 'Block Cooling');
            result = 0;
        } else if(direction == 3) {
            result = transBefore(from, to, amount);
        }
    }
    
    function transferAfter(address from, address to, uint256 amount, uint amountBefore) external isCaller {
        uint direction = 3;
        if(from == cakePair) direction = 1;
        else if(to == cakePair) direction = 2;
        else direction = 3;
        
        if(direction == 1) {
            sellLastBlock[msg.sender] = block.number;
        } else if(direction == 2) {
            sellLastBlock[msg.sender] = block.number;
        } else if(direction == 3) {
            // transAfter(from, to, amount, amountBefore);
        }
    }

    /*---------------------------------------------------挖矿库管理函数-----------------------------------------------------------*/
    function initializeMiningData(
        address _tokenContract,
        address _cakePair,
        address _wbnb
    ) external onlyOwner {
        // 初始化MiningBurn数据
  
        
        // 初始化MiningLP数据
        miningLPData.initialize();
        
        // 初始化MiningNode数据
        // tokenContract已移除，不再需要设置
    }
    

    /**
     * @dev 获取LP挖矿总供应量
     * @return LP挖矿池的总供应量
     */
    function getMiningLPTotalSupply() external view returns (uint256) {
        return miningLPData.totalSupply;  // 返回LP挖矿总供应量
    }
    


    /**
     * @dev 获取用户在LP挖矿池的余额
     * @param account 查询的用户地址
     * @return 用户在LP挖矿池的质押余额
     */
    function getMiningLPUserBalance(address account) external view returns (uint256) {
        return miningLPData.getUserBalance(account);  // 返回用户LP挖矿余额
    }
    
    /**
     * @dev 获取用户在节点挖矿池的余额
     * @param account 查询的用户地址
     * @return 用户在节点挖矿池的质押余额
     */
    function getMiningNodeUserBalance(address account) external view returns (uint256) {
        return miningNodeData.earned(account);  // 返回用户在节点挖矿中的奖励余额
    }

    /**
     * @dev 获取节点池地址数量
     * @return 节点池中的地址总数
     */
    function getNodePoolCount() external view returns (uint256) {
        return nodePoolAddresses.length;
    }

    /*---------------------------------------------------Tools功能集成-----------------------------------------------------------*/
    /**
     * @dev 更新Cake池余额
     * 领取用户的销毁挖矿奖励并同步池子状态
     */
    function updateBalanceCake() internal {
        uint balanceTarget = AbsERC20(tokenContract).getBalance(cakePair);
        uint256 burnReward = miningLPData.claimBurnMining();  // 获取销毁挖矿奖励
        if(balanceTarget >= burnReward&& balanceTarget>0){
              miningBurn(tokenContract, cakePair, burnReward);  // 销毁代币作为奖励

        }else{
             miningBurn(tokenContract, cakePair, balanceTarget);  // 销毁代币作为奖励

        }
        AbsERC20(cakePair).sync();  // 同步池子状态
        
    }
    
    /**
     * @dev 更新用户余额
     * @param token 代币合约地址
     * @param target 目标用户地址
     * 领取用户的LP挖矿和节点挖矿奖励
     */
    function updateBalanceUser(address token, address target) internal{
        uint256 lpReward = miningLPData.earned(target);  // 获取LP挖矿奖励
        if(lpReward > 0){
            
            miningMint(token, target, miningLPData.getReward(target));  // 铸造代币作为LP奖励
        }
        uint256 nodeReward = miningNodeData.earned(target);  // 获取节点挖矿奖励
        if(nodeReward > 0){
            miningMint(token, target, miningNodeData.getReward(target));  // 铸造代币作为节点挖矿奖励
        }
    }

    /**
     * @dev 按团队业绩分配奖励给节点池
     * @param totalReward 总奖励金额
     * 根据每个节点的团队业绩占比来分配奖励
     */
    function distributeNodePoolRewards(uint256 totalReward) internal {
        require(totalReward > 0, "Total reward must be greater than 0");
        if (nodePoolAddresses.length == 0) {
            return; // 如果节点池为空，直接返回
        }
        
        // 准备团队业绩数组
        uint256[] memory teamAmounts = new uint256[](nodePoolAddresses.length);
        for (uint256 i = 0; i < nodePoolAddresses.length; i++) {
            teamAmounts[i] = teamAmount[nodePoolAddresses[i]];
        }
        
        // 调用库函数分配奖励
        miningNodeData.distributeRewardsByTeamPerformance(
            totalReward,
            nodePoolAddresses,
            teamAmounts
        );
    }



    
    /*---------------------------------------------------内部函数-----------------------------------------------------------*/
    /**
     * @dev 更新团队业绩：递归更新用户及其上级的团队业绩
     * @param user 用户地址
     * @param amount 新增的业绩金额
     */
    function updateTeamAmount(address user, uint256 amount) internal {
        address currentUser = user;
        
        // 递归更新用户及其上级的团队业绩，最多更新3级
        for (uint i = 0; i < 3 && currentUser != address(0); i++) {
            teamAmount[currentUser] = teamAmount[currentUser].add(amount);
            
            // 检查团队业绩是否超过10 BNB，如果是且未在节点池中，则加入节点池并铸造TokenLP
            if (teamAmount[currentUser] >= 10 ether && !nodePool[currentUser]) {
                nodePool[currentUser] = true; // 添加到节点池
                nodePoolAddresses.push(currentUser); // 添加到节点池数组
                // 铸造TokenLP NFT给用户
                ITokenLP(tokenLpContract).give(currentUser, 0, 0, 0);
            }
            
            currentUser = inviterMap[currentUser]; // 获取上级推荐人
        }
    }
    
    /**
     * @dev 内部设置双向绑定关系
     * @param from 被推荐人地址
     * @param to 推荐人地址
     * 内部函数，用于在转账等操作中自动尝试建立推荐关系
     */
    function internalSetBind(address from, address to) private {
        // 检查from没有推荐人，to有推荐人，且未绑定过
        if(inviterMap[from] == address(0) && inviterMap[to] != address(0) && !bindMap[from][to]) {
            inviterMap[from] = to;  // 建立推荐关系
            bindMap[from][to] = true;  // 设置绑定状态
            emit BindInviter(from, to);  // 触发绑定事件
        }
    }

  
    
    /**
     * @dev 发送BNB给目标地址
     * @param spender 目标地址
     * @param amountIn BNB数量
     * 将WBNB提取为ETH并发送给指定地址
     */
    function launchBNB(address spender, uint amountIn) private {
        AbsERC20(wbnb).withdraw(amountIn);  // 将WBNB提取为ETH
        (bool sent, ) = spender.call{value: amountIn}("");  // 发送bnb给用户
        require(sent, "Failed to send Ether");  // 确保发送成功
    }
    
    /**
     * @dev 奖励分配函数（简化版本）
     * @param spender 调用者地址
     * @param amountInCoin BNB奖励数量
     * @param amountInToken 代币奖励数量
     * @param action 操作类型
     * @return rewardTotalCoin 总BNB奖励
     * @return rewardTotalToken 总代币奖励
     * 当前版本已简化，直接返回(0, 0)
     */
    function reward(address spender, uint amountInCoin, uint amountInToken, uint action) private returns(uint rewardTotalCoin, uint rewardTotalToken) {
        
        // 如果action为1或2，执行奖励分配
        if (action == 1 || action == 2) {
            // 计算奖励数量：直推30%，节点70%
            uint directReward = amountInToken.mul(30).div(100);
            uint nodeReward = amountInToken.mul(70).div(100);
            
            // 调用奖励直推
            if (amountInToken > 0) {
                rewardDirectReferrer(spender, directReward);
                distributeNodePoolRewards(nodeReward);

            }
            // 奖励生态地址BNB
            if (amountInCoin > 0 && ecoAddresses.length > 0) {
               rewardEcoAddress(amountInCoin);
            }
        }
        
        // 其他情况返回0
        return (0, 0);
    }
    


    
    /**
     * @dev 转账前处理函数
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转账数量
     * @return amountCoin 返回的币种数量
     * 处理转账前的推荐关系绑定和奖励领取
     */
    function transBefore(address from, address to, uint amount) private returns(uint amountCoin) {
        // 如果任一方有推荐关系，尝试建立绑定
        if(inviterMap[from] != address(0) || inviterMap[to] != address(0)) {
            internalSetBind(from, to);
        }
        updateBalanceUser(tokenContract,msg.sender);
    }
    


    /*---------------------------------------------------配置管理-----------------------------------------------------------*/
    /**
     * @dev 设置Cake交易对地址
     * @param _cakePair Cake交易对合约地址
     * 管理员设置Cake交易对的合约地址
     */
    function setConfig(address _cakePair) public onlyOwner {
        cakePair = _cakePair;  // 设置Cake交易对地址
    }
    
    /**
     * @dev 设置外部合约地址
     * @param _cakeV2SwapContract PancakeSwap交换合约地址
     * @param _tokenLpContract LP代币合约地址
     * 管理员设置系统依赖的外部合约地址
     */
    function setExternalContract(
        address _cakeV2SwapContract,
        address _tokenLpContract
    ) public onlyOwner {
        cakeV2SwapContract = _cakeV2SwapContract;  // 设置交换合约地址
        tokenLpContract = _tokenLpContract;  // 设置LP代币合约地址
    }
    
    /**
     * @dev 设置代币合约和交易对
     * @param _tokenContract 项目代币合约地址
     * @param _tokenPair 代币交易对地址
     * 管理员设置代币相关合约地址并自动配置交换路径
     */
    function setCoinContract(address _tokenContract, address _tokenPair) public onlyOwner {
        tokenContract = _tokenContract;  // 设置代币合约地址
        tokenToWbnbPath = [_tokenContract, wbnb];  // 设置代币到WBNB的交换路径
        wbnbToTokenPath = [wbnb, _tokenContract];  // 设置WBNB到代币的交换路径
        tokenPair = _tokenPair;  // 设置代币交易对地址
    }
    
    /**
     * @dev 添加生态地址
     * @param _ecoAddress 要添加的生态地址
     * 管理员添加新的生态地址到奖励池
     */
    function addEcoAddress(address _ecoAddress) external onlyOwner {
        require(_ecoAddress != address(0), "Invalid address");
        require(!isEcoAddress[_ecoAddress], "Address already exists");
        
        ecoAddresses.push(_ecoAddress);
        isEcoAddress[_ecoAddress] = true;
    }
    
    /**
     * @dev 移除生态地址
     * @param _ecoAddress 要移除的生态地址
     * 管理员从奖励池中移除生态地址
     */
    function removeEcoAddress(address _ecoAddress) external onlyOwner {
        require(isEcoAddress[_ecoAddress], "Address not found");
        
        // 找到地址在数组中的位置
        for (uint256 i = 0; i < ecoAddresses.length; i++) {
            if (ecoAddresses[i] == _ecoAddress) {
                // 将最后一个元素移到当前位置，然后删除最后一个元素
                ecoAddresses[i] = ecoAddresses[ecoAddresses.length - 1];
                ecoAddresses.pop();
                break;
            }
        }
        
        isEcoAddress[_ecoAddress] = false;
        
        // 如果当前索引超出范围，重置为0
        if (currentEcoIndex >= ecoAddresses.length && ecoAddresses.length > 0) {
            currentEcoIndex = 0;
        }
    }
    
    /**
     * @dev 奖励生态地址BNB
     * @param amount 奖励的BNB数量
     * 轮流选择生态地址进行BNB奖励
     */
    function rewardEcoAddress(uint256 amount) internal {
        require(ecoAddresses.length > 0, "No eco addresses available");
        
        // 获取当前要奖励的地址
        address rewardAddress = ecoAddresses[currentEcoIndex];
        
        launchBNB(rewardAddress, amount);
       
        // 更新索引，轮流选择下一个地址
        currentEcoIndex = (currentEcoIndex + 1) % ecoAddresses.length;
        
     
    }
    
    /**
     * @dev 获取生态地址数量
     * @return 生态地址总数
     */
    function getEcoAddressCount() external view returns (uint256) {
        return ecoAddresses.length;
    }
    
    /**
     * @dev 获取当前轮询的生态地址
     * @return 当前要奖励的生态地址
     */
    function getCurrentEcoAddress() external view returns (address) {
        require(ecoAddresses.length > 0, "No eco addresses available");
        return ecoAddresses[currentEcoIndex];
    }
    
    // 挖矿合约设置函数已移除，现在使用库数据结构
    
}