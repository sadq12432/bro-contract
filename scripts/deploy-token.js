const { ethers } = require("hardhat");

async function main() {
  console.log("开始部署Token合约到BSC测试网络...");

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);

  // 获取账户余额
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("账户余额:", ethers.formatEther(balance), "BNB");

  // 部署Token合约
  console.log("正在部署Token合约...");
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy();
  
  // 等待部署完成
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  
  console.log("Token合约部署成功!");
  console.log("合约地址:", tokenAddress);
  console.log("交易哈希:", token.deploymentTransaction().hash);
  
  // 验证合约部署
  console.log("验证合约部署...");
  const name = await token.name();
  const symbol = await token.symbol();
  const totalSupply = await token.totalSupply();
  
  console.log("代币名称:", name);
  console.log("代币符号:", symbol);
  console.log("总供应量:", ethers.formatEther(totalSupply));
  
  console.log("\n部署完成! 请保存合约地址:", tokenAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  });