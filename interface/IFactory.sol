// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface IFactory {

    function getTotalOutputLP() external view returns (uint256 result);                         //查询 | 总LP产出
    function getTotalOutputBurn() external view returns (uint256 result);                       //查询 | 总燃烧产出

    function getCurrentOutputLP(address account) external view returns (uint256 result);        //查询 | 当前LP产出量
    function getCurrentOutputPartner(address account) external view returns (uint256 result);   //查询 | 当前合伙人池产出量
    function getCurrentOutputNode(address account) external view returns (uint256 result);      //查询 | 当前节点池产出量
    function getCurrentOutputBurn(address account) external view returns (uint256 result);      //查询 | 当前燃烧产出量
    function recCurrentOutputLP(address account) external returns (uint256 result);             //领取 | 当前LP产出量
    function recCurrentOutputPartner(address account) external returns (uint256 result);        //领取 | 当前合伙人池产出量
    function recCurrentOutputNode(address account) external returns (uint256 result);           //领取 | 当前节点产出量
    function recCurrentOutputBurn(address account) external returns (uint256 result);           //领取 | 当前燃烧产出量
    function recCurrentOutputLock(address from,address to) external returns (uint256 result);   //领取 | 当前锁仓产出量

    function updOutput(uint cakePoolAmount) external ;                                          //更新 | 产量
    function updCheck(address account) external ;                                               //更新 | LP底池缓存
}
