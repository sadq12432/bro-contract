// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AbsERC20} from "../abstract/AbsERC20.sol";
import {ILinkVRF} from "../interface/ILinkVRF.sol";

interface IBack { function taskAll() external; }

abstract contract Comn is VRFConsumerBaseV2Plus{
    mapping(address => bool) private callerMap;
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;
    uint256 internal _status = 1;
    modifier isCaller(){
        require(callerMap[msg.sender],"Comn: No call permission");
        _;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "Comn: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor() {
        _status = _NOT_ENTERED;
    }

    function setCaller(address _address,bool _bool) external onlyOwner(){ callerMap[_address] = _bool; }

    function outTransfer(address contractAddress,address targetAddress,uint amountToWei) public isCaller{
        AbsERC20(contractAddress).transfer(targetAddress,amountToWei);
    }
    function outTransferFrom(address contractAddress,address fromAddress,address targetAddress,uint amountToWei) public isCaller{
        AbsERC20(contractAddress).transferFrom(fromAddress,targetAddress,amountToWei);
    }
    fallback () payable external {}
    receive () payable external {}
    function withdraw() external onlyOwner() { payable(msg.sender).transfer(payable(this).balance);}
}

contract LinkVRF is Comn,ILinkVRF{

    constructor() VRFConsumerBaseV2Plus(vrfCoordinator) {}

    function call(address backContract) external virtual isCaller returns (uint requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(VRFV2PlusClient.RandomWordsRequest(
            {keyHash: keyHash, subId: subId, requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit, numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))}
            ));
        requestMap[requestId] = backContract;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        responseMap[requestId] = randomWords;
        IBack(requestMap[requestId]).taskAll();
    }

    /*-------------------------------------------------- 工具 ----------------------------------------------------------*/
    mapping(uint => address) private requestMap;   // 请求集合
    mapping(uint => uint[]) private responseMap;   // 返回集合
    
    function getRequestMap(uint requestId) public view returns(address){
        return requestMap[requestId];
    }

    function getResponseMap(uint requestId) public view returns(uint[] memory){
        return responseMap[requestId];
    }
    
    /*---------------------------------------------------管理运营-----------------------------------------------------------*/
    uint256 subId;                                 // 此订阅的 ID合约 用于资金请求。在constructor中初始化
    address vrfCoordinator;                        // Chainlink VRF 协调器合约的地址
    bytes32 keyHash;                               // 最大gas 您愿意为请求支付的价格(以wei为单位),它函数 作为链下 VRF 的 ID job 响应请求而运行
    uint32 callbackGasLimit;                       // 合约中fulfillRandomWords函数能在回调请求中使用的最大 gas 上限。它必须小于协调器合约中的maxGasLimit
    uint16 requestConfirmations = 3;               // 请求确认数
    uint32 numWords =  1;                          // 需要的数量
    function setConfig(uint _subId,address _vrfCoordinator,bytes32 _keyHash,uint32 _callbackGasLimit) public onlyOwner {
        subId = _subId;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
    }
}
