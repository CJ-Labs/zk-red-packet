// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/BN254.sol";

interface IRedPacketVerifier {
    struct Proof {
        BN254.G1Point A;
        BN254.G2Point B;
        BN254.G1Point C;
    }
    
    /// @notice 验证零知识证明
    /// @param proof Groth16证明结构
    /// @param inputs 公开输入数组
    /// @return 验证是否通过
    function verifyProof(
        Proof calldata proof,
        uint256[2] calldata inputs
    ) external returns (bool);

    /// @notice 获取验证密钥的哈希值
    /// @return 验证密钥的keccak256哈希
    function verifyingKeyHash() external view returns (bytes32);
} 