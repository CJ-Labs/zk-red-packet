// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IRedPacketVerifier.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/BN254.sol";

contract RedPacketVerifier is IRedPacketVerifier {
    using BN254 for BN254.G1Point;
    using BN254 for BN254.G2Point;

    struct VerifyingKey {
        BN254.G1Point alpha1;
        BN254.G2Point beta2;
        BN254.G2Point gamma2;
        BN254.G2Point delta2;
        mapping(uint256 => BN254.G1Point) IC;
        uint256 ICLength;
    }

    VerifyingKey private verifyingKey;
    
    event ProofVerified(bool success, bytes32 indexed inputHash);

    constructor(
        uint256[2] memory alpha1,
        uint256[4] memory beta2,
        uint256[4] memory gamma2,
        uint256[4] memory delta2,
        uint256[2][] memory IC
    ) {
        require(IC.length > 0, "Invalid IC length");
        require(
            alpha1[0] < BN254.FP_MODULUS && alpha1[1] < BN254.FP_MODULUS,
            "Invalid alpha1"
        );

        verifyingKey.alpha1 = BN254.G1Point(alpha1[0], alpha1[1]);
        verifyingKey.beta2 = BN254.G2Point(
            [beta2[0], beta2[1]],
            [beta2[2], beta2[3]]
        );
        verifyingKey.gamma2 = BN254.G2Point(
            [gamma2[0], gamma2[1]],
            [gamma2[2], gamma2[3]]
        );
        verifyingKey.delta2 = BN254.G2Point(
            [delta2[0], delta2[1]],
            [delta2[2], delta2[3]]
        );

        verifyingKey.ICLength = IC.length;
        for (uint256 i = 0; i < IC.length; i++) {
            verifyingKey.IC[i] = BN254.G1Point(IC[i][0], IC[i][1]);
        }
    }

    function verifyProof(
        Proof calldata proof,
        uint256[2] calldata inputs
    ) external returns (bool) {
        require(proof.A.X < BN254.FP_MODULUS && proof.A.Y < BN254.FP_MODULUS, "Invalid proof.A");
        require(inputs.length + 1 == verifyingKey.ICLength, "Invalid input length");

        BN254.G1Point memory vk_x = _computeLinearCombination(inputs);

        bool success = _verifyPairing(proof, vk_x);
        
        emit ProofVerified(success, keccak256(abi.encode(inputs)));
        
        return success;
    }

    function _computeLinearCombination(
        uint256[2] calldata inputs
    ) private view returns (BN254.G1Point memory) {
        BN254.G1Point memory vk_x = BN254.G1Point(0, 0);
        
        for (uint256 i = 0; i < inputs.length; i++) {
            require(inputs[i] < BN254.FP_MODULUS, "Input is not in field");
            vk_x = BN254.plus(
                vk_x,
                BN254.scalar_mul(verifyingKey.IC[i + 1], inputs[i])
            );
        }
        return BN254.plus(vk_x, verifyingKey.IC[0]);
    }

    function _verifyPairing(
        Proof calldata proof,
        BN254.G1Point memory vk_x
    ) private view returns (bool) {
        BN254.G1Point memory a1 = proof.A;
        BN254.G2Point memory a2 = proof.B;
        
        BN254.G1Point memory b1 = BN254.negate(vk_x);
        BN254.G2Point memory b2 = verifyingKey.gamma2;
        
        BN254.G1Point memory c1 = BN254.negate(proof.C);
        BN254.G2Point memory c2 = verifyingKey.delta2;
        
        BN254.G1Point memory d1 = BN254.negate(verifyingKey.alpha1);
        BN254.G2Point memory d2 = verifyingKey.beta2;

        return BN254.pairing(a1, a2, b1, b2) &&
               BN254.pairing(c1, c2, d1, d2);
    }

    function verifyingKeyHash() external view override returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                verifyingKey.alpha1.X,
                verifyingKey.alpha1.Y,
                verifyingKey.beta2.X,
                verifyingKey.beta2.Y,
                verifyingKey.gamma2.X,
                verifyingKey.gamma2.Y,
                verifyingKey.delta2.X,
                verifyingKey.delta2.Y
            )
        );
    }
} 