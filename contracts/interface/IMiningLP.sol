// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface IMiningLP {
    function earned(address account) external view returns (uint256 result);         //查询
    function getReward(address account) external returns (uint256 result);           //领取
    function stake(address account,uint cost,uint weight) external returns (uint256 result);  //质押
    function withdraw(address account,uint number) external;                         //赎回

    function updateOutput(uint cakePoolAmount) external returns(uint outputToWei);   //更新产量

    function getTotalOutput() external view returns (uint256 result);                // 查询全网总产出
    function getQuotaUser(address account) external view returns (uint256 result);   // 查询累计额度
    function getExtractUser(address account) external view returns (uint256 result); // 查询累计提取
    function getStakeUser(address account) external view returns (uint256 result);   // 查询用户当前质押
    function getStakeAdmin(address account) external view returns (uint256 result);  // 查询管理员当前质押
}
