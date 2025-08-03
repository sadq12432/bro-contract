// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^ 0.8.24;

interface ILinkVRF {
    function call(address backContract) external returns(uint requestId);
}
