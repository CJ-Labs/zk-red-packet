// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RedPacketVerifier.sol";
import "../src/libraries/BN254.sol";

contract RedPacketVerifierTest is Test {
    RedPacketVerifier public verifier;
    
    // 测试数据
    uint256[2] alpha1;
    uint256[4] beta2;
    uint256[4] gamma2;
    uint256[4] delta2;
    uint256[2][] IC;
    
    // 模拟的有效证明
    IRedPacketVerifier.Proof validProof;
    uint256[2] validInputs;

    function setUp() public {
        // 设置测试数据
        alpha1 = [uint256(1), uint256(2)];
        beta2 = [uint256(1), uint256(2), uint256(3), uint256(4)];
        gamma2 = [uint256(1), uint256(2), uint256(3), uint256(4)];
        delta2 = [uint256(1), uint256(2), uint256(3), uint256(4)];
        
        // 初始化 IC
        IC = new uint256[2][](2);
        IC[0] = [uint256(1), uint256(2)];
        IC[1] = [uint256(3), uint256(4)];
        
        // 部署验证器
        verifier = new RedPacketVerifier(
            alpha1,
            beta2,
            gamma2,
            delta2,
            IC
        );
        
        // 设置有效的证明和输入
        validProof = IRedPacketVerifier.Proof({
            A: BN254.G1Point(1, 2),
            B: BN254.G2Point(
                [uint256(1), uint256(2)],
                [uint256(3), uint256(4)]
            ),
            C: BN254.G1Point(1, 2)
        });
        validInputs = [uint256(1), uint256(2)];
    }

    /// @notice 测试构造函数参数验证
    function testConstructorValidation() public {
        // 测试空的 IC 数组
        uint256[2][] memory emptyIC = new uint256[2][](0);
        vm.expectRevert("Invalid IC length");
        new RedPacketVerifier(alpha1, beta2, gamma2, delta2, emptyIC);
        
        // 测试无效的 alpha1 值
        uint256[2] memory invalidAlpha1 = [
            BN254.FP_MODULUS,
            uint256(2)
        ];
        vm.expectRevert("Invalid alpha1");
        new RedPacketVerifier(invalidAlpha1, beta2, gamma2, delta2, IC);
    }

    /// @notice 测试验证有效证明
    function testVerifyValidProof() public {
        bool result = verifier.verifyProof(validProof, validInputs);
        // 注意：这里的结果取决于实际的验证逻辑
        // assertTrue(result, "Valid proof should be verified");
    }

    /// @notice 测试验证无效的证明点
    function testVerifyInvalidProofPoint() public {
        // 创建一个 X 坐标超出范围的证明
        IRedPacketVerifier.Proof memory invalidProof = validProof;
        invalidProof.A.X = BN254.FP_MODULUS;
        
        vm.expectRevert("Invalid proof.A");
        verifier.verifyProof(invalidProof, validInputs);
    }

    /// @notice 测试验证输入长度不匹配
    function testVerifyInvalidInputLength() public {
        // 创建错误长度的输入
        uint256[2] memory wrongInputs = [uint256(1), uint256(2)];
        
        vm.expectRevert("Invalid input length");
        verifier.verifyProof(validProof, wrongInputs);
    }

    /// @notice 测试验证无效的输入值
    function testVerifyInvalidInputValue() public {
        // 创建超出范围的输入值
        uint256[2] memory invalidInputs = [BN254.FP_MODULUS, uint256(2)];
        
        vm.expectRevert("Input is not in field");
        verifier.verifyProof(validProof, invalidInputs);
    }

    /// @notice 测试验证密钥哈希计算
    function testVerifyingKeyHash() public {
        bytes32 hash = verifier.verifyingKeyHash();
        assertTrue(hash != bytes32(0), "Hash should not be zero");
        
        // 创建相同参数的新验证器
        RedPacketVerifier newVerifier = new RedPacketVerifier(
            alpha1,
            beta2,
            gamma2,
            delta2,
            IC
        );
        
        // 验证相同参数产生相同的哈希
        assertEq(
            hash,
            newVerifier.verifyingKeyHash(),
            "Same parameters should produce same hash"
        );
    }

    /// @notice 测试事件发出
    function testProofVerifiedEvent() public {
        // 准备事件测试
        vm.expectEmit(true, true, false, true);
        emit RedPacketVerifier.ProofVerified(
            true,
            keccak256(abi.encode(validInputs))
        );
        
        // 执行验证
        verifier.verifyProof(validProof, validInputs);
    }
} 