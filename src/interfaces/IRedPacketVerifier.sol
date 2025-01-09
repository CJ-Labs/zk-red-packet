// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRedPacketVerifier {
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }
    
    function verifyProof(
        Proof calldata proof,
        uint256[2] calldata inputs
    ) external view returns (bool);
} 