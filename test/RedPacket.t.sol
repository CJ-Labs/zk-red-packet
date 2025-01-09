// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RedPacket.sol";
import "../src/RedPacketVerifier.sol";
import "../src/libraries/Poseidon.sol";
import "../src/libraries/BN254.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract RedPacketTest is Test {
    RedPacket public redPacket;
    RedPacketVerifier public verifier;
    Poseidon public poseidonContract;
    
    // 测试账户
    address public alice = address(1);
    address public bob = address(2);
    address public carol = address(3);
    
    // 测试常量
    uint256 public constant AMOUNT_PER_PACKET = 1 ether;
    uint256 public constant PACKET_COUNT = 5;
    uint256 public constant DURATION = 1 days;
    bytes32 public constant MERKLE_ROOT = bytes32(uint256(1));
    
    // 模拟的证明数据
    IRedPacketVerifier.Proof mockProof;
    string password = "test123";

    function setUp() public {
        // 部署合约
        poseidonContract = new Poseidon();
        
        // 部署验证器（使用测试参数）
        uint256[2] memory alpha1 = [uint256(1), uint256(2)];
        uint256[4] memory beta2 = [uint256(1), uint256(2), uint256(3), uint256(4)];
        uint256[4] memory gamma2 = [uint256(1), uint256(2), uint256(3), uint256(4)];
        uint256[4] memory delta2 = [uint256(1), uint256(2), uint256(3), uint256(4)];
        uint256[2][] memory IC = new uint256[2][](2);
        IC[0] = [uint256(1), uint256(2)];
        IC[1] = [uint256(3), uint256(4)];
        
        verifier = new RedPacketVerifier(
            alpha1,
            beta2,
            gamma2,
            delta2,
            IC
        );
        
        // 部署红包合约
        redPacket = new RedPacket(
            address(verifier),
            address(poseidonContract)
        );
        
        // 设置账户余额
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        
        // 设置模拟证明
        mockProof = IRedPacketVerifier.Proof({
            A: BN254.G1Point(1, 2),
            B: BN254.G2Point(
                [uint256(1), uint256(2)],
                [uint256(3), uint256(4)]
            ),
            C: BN254.G1Point(1, 2)
        });
    }

    /// @notice 测试创建固定金额红包
    function testCreateFixedPacket() public {
        vm.startPrank(alice);
        
        uint256 packetId = redPacket.createFixedPacket{value: 5 ether}(
            PACKET_COUNT,
            AMOUNT_PER_PACKET,
            MERKLE_ROOT,
            DURATION
        );
        
        (
            address creator,
            uint256 totalAmount,
            uint256 remainingAmount,
            uint256 count,
            uint256 remainingCount,
            RedPacket.PacketType packetType,
            RedPacket.Status status,
            bytes32 merkleRoot,
            uint256 createdAt,
            uint256 expiresAt
        ) = redPacket.packets(packetId);

        assertEq(creator, alice);
        assertEq(totalAmount, 5 ether);
        assertEq(count, PACKET_COUNT);
        assertEq(uint8(status), uint8(RedPacket.Status.ACTIVE));
        assertEq(expiresAt, block.timestamp + DURATION);
        
        vm.stopPrank();
    }

    /// @notice 测试创建随机金额红包
    function testCreateRandomPacket() public {
        vm.startPrank(alice);
        
        uint256 totalAmount = 10 ether;
        uint256 packetId = redPacket.createRandomPacket{value: totalAmount}(
            PACKET_COUNT,
            MERKLE_ROOT,
            DURATION
        );
        
        (
            address creator,
            uint256 amount,
            uint256 remainingAmount,
            uint256 count,
            uint256 remainingCount,
            RedPacket.PacketType packetType,
            RedPacket.Status status,
            bytes32 merkleRoot,
            uint256 createdAt,
            uint256 expiresAt
        ) = redPacket.packets(packetId);

        assertEq(creator, alice);
        assertEq(amount, totalAmount);
        assertEq(count, PACKET_COUNT);
        assertEq(uint8(packetType), uint8(RedPacket.PacketType.RANDOM));
        
        vm.stopPrank();
    }

    /// @notice 测试领取红包
    function testClaimPacket() public {
        // 创建红包
        vm.startPrank(alice);
        uint256 packetId = redPacket.createFixedPacket{value: 5 ether}(
            PACKET_COUNT,
            AMOUNT_PER_PACKET,
            MERKLE_ROOT,
            DURATION
        );
        vm.stopPrank();
        
        // Bob 领取红包
        vm.startPrank(bob);
        uint256 beforeBalance = bob.balance;
        
        bytes32[] memory merkleProof = new bytes32[](0);
        
        redPacket.claimPacket(
            packetId,
            merkleProof,
            mockProof,
            password
        );
        
        assertEq(bob.balance - beforeBalance, AMOUNT_PER_PACKET);
        vm.stopPrank();
    }

    /// @notice 测试过期红包退回
    function testRefundExpiredPacket() public {
        vm.startPrank(alice);
        
        uint256 packetId = redPacket.createFixedPacket{value: 5 ether}(
            PACKET_COUNT,
            AMOUNT_PER_PACKET,
            MERKLE_ROOT,
            DURATION
        );
        
        // 快进时间
        vm.warp(block.timestamp + DURATION + 1);
        
        uint256 beforeBalance = alice.balance;
        redPacket.refundExpiredPacket(packetId);
        
        assertEq(alice.balance - beforeBalance, 5 ether);
        
        (
            ,,,,,, // 跳过前面的字段
            RedPacket.Status status,
            ,, // 跳过后面的字段
        ) = redPacket.packets(packetId);
        assertEq(uint8(status), uint8(RedPacket.Status.EXPIRED));
        
        vm.stopPrank();
    }

    /// @notice 测试合约暂停功能
    function testPause() public {
        // 非所有者不能暂停
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        redPacket.pause();
        vm.stopPrank();
        
        // 所有者可以暂停
        redPacket.pause();
        
        // 暂停后不能创建红包
        vm.startPrank(alice);
        vm.expectRevert("Pausable: paused");
        redPacket.createFixedPacket{value: 5 ether}(
            PACKET_COUNT,
            AMOUNT_PER_PACKET,
            MERKLE_ROOT,
            DURATION
        );
        vm.stopPrank();
    }

    /// @notice 测试随机红包金额分配
    function testRandomPacketDistribution() public {
        vm.startPrank(alice);
        
        uint256 totalAmount = 10 ether;
        uint256 packetId = redPacket.createRandomPacket{value: totalAmount}(
            PACKET_COUNT,
            MERKLE_ROOT,
            DURATION
        );
        vm.stopPrank();
        
        // 多个用户领取红包
        address[] memory users = new address[](PACKET_COUNT);
        uint256[] memory amounts = new uint256[](PACKET_COUNT);
        bytes32[] memory merkleProof = new bytes32[](0);
        
        for(uint i = 0; i < PACKET_COUNT; i++) {
            users[i] = address(uint160(i + 1000));
            vm.deal(users[i], 1 ether);
            
            vm.startPrank(users[i]);
            uint256 beforeBalance = users[i].balance;
            
            redPacket.claimPacket(
                packetId,
                merkleProof,
                mockProof,
                password
            );
            
            amounts[i] = users[i].balance - beforeBalance;
            vm.stopPrank();
        }
        
        // 验证总和等于总金额
        uint256 sum = 0;
        for(uint i = 0; i < amounts.length; i++) {
            sum += amounts[i];
        }
        assertEq(sum, totalAmount);
    }

    /// @notice 测试完整的红包发放和领取流程
    function testCompleteRedPacketFlow() public {
        // 1. 准备默克尔树数据
        address[] memory allowList = new address[](PACKET_COUNT);
        bytes32[] memory leaves = new bytes32[](PACKET_COUNT);
        
        // 为每个允许的地址生成默克尔叶子
        for(uint i = 0; i < PACKET_COUNT; i++) {
            allowList[i] = address(uint160(i + 1000));
            
            // 计算每个地址的 Poseidon 哈希
            uint256[2] memory inputs;
            inputs[0] = uint256(uint160(allowList[i]));
            inputs[1] = uint256(keccak256(abi.encodePacked(password, i + 1))); // 每个用户的密码加上索引
            
            leaves[i] = bytes32(poseidonContract.hash(inputs));
        }
        
        // 2. 构建默克尔树根
        bytes32 merkleRoot = _buildMerkleRoot(leaves);
        
        // 3. Alice 创建固定金额红包
        vm.startPrank(alice);
        uint256 totalAmount = AMOUNT_PER_PACKET * PACKET_COUNT;
        uint256 packetId = redPacket.createFixedPacket{value: totalAmount}(
            PACKET_COUNT,
            AMOUNT_PER_PACKET,
            merkleRoot,
            DURATION
        );
        vm.stopPrank();
        
        // 4. 验证红包创建成功
        (
            ,
            uint256 amount,
            uint256 remainingAmount,
            uint256 count,
            uint256 remainingCount,
            ,,,, // 跳过其他字段
        ) = redPacket.packets(packetId);
        
        assertEq(amount, totalAmount);
        assertEq(remainingAmount, totalAmount);
        assertEq(count, PACKET_COUNT);
        assertEq(remainingCount, PACKET_COUNT);
        
        // 5. 允许列表中的用户依次领取红包
        bytes32[] memory proof; // 声明在外部避免重复
        
        for(uint i = 0; i < PACKET_COUNT; i++) {
            address user = allowList[i];
            vm.deal(user, 1 ether);
            
            vm.startPrank(user);
            
            // 构建默克尔证明
            proof = _generateMerkleProof(leaves, i);
            
            // 验证默克尔证明是否有效
            assertTrue(
                MerkleProof.verify(
                    proof,
                    merkleRoot,
                    leaves[i]
                ),
                "Invalid merkle proof"
            );
            
            // 构建零知识证明输入
            uint256[2] memory proofInputs;
            proofInputs[0] = packetId;
            proofInputs[1] = uint256(leaves[i]);
            
            // 记录领取前的余额
            uint256 beforeBalance = user.balance;
            
            // 领取红包
            redPacket.claimPacket(
                packetId,
                proof,
                _generateProof(proofInputs),
                string(abi.encodePacked(password, i + 1))
            );
            
            // 验证领取结果
            assertEq(user.balance - beforeBalance, AMOUNT_PER_PACKET);
            
            vm.stopPrank();
            
            // 验证红包状态更新
            (
                ,
                ,
                uint256 newRemainingAmount,
                ,
                uint256 newRemainingCount,
                ,,,, // 跳过其他字段
            ) = redPacket.packets(packetId);
            
            assertEq(newRemainingAmount, totalAmount - AMOUNT_PER_PACKET * (i + 1));
            assertEq(newRemainingCount, PACKET_COUNT - (i + 1));
        }
        
        // 6. 验证红包已被领完
        (
            ,
            ,
            uint256 finalRemainingAmount,
            ,
            uint256 finalRemainingCount,
            ,
            RedPacket.Status finalStatus,
            ,, // 跳过其他字段
        ) = redPacket.packets(packetId);
        
        assertEq(finalRemainingAmount, 0);
        assertEq(finalRemainingCount, 0);
        assertEq(uint8(finalStatus), uint8(RedPacket.Status.FINISHED));
        
        // 7. 尝试再次领取（应该失败）
        vm.startPrank(allowList[0]);
        proof = _generateMerkleProof(leaves, 0);
        vm.expectRevert("Packet not active");
        redPacket.claimPacket(
            packetId,
            proof,
            mockProof,
            password
        );
        vm.stopPrank();
    }

    /// @notice 构建默克尔树根
    function _buildMerkleRoot(bytes32[] memory leaves) private pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        
        bytes32[] memory currentLevel = leaves;
        
        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            
            for (uint i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    nextLevel[i/2] = keccak256(abi.encodePacked(currentLevel[i], currentLevel[i+1]));
                } else {
                    nextLevel[i/2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
        }
        
        return currentLevel[0];
    }

    /// @notice 生成默克尔证明
    function _generateMerkleProof(bytes32[] memory leaves, uint256 index) private pure returns (bytes32[] memory) {
        require(index < leaves.length, "Index out of bounds");
        
        uint256 depth = 0;
        uint256 n = leaves.length;
        while (n > 1) {
            n = (n + 1) / 2;
            depth++;
        }
        
        bytes32[] memory merkleProof = new bytes32[](depth);
        bytes32[] memory currentLevel = leaves;
        uint256 currentIndex = index;
        uint256 proofIndex = 0;
        
        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            
            for (uint i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    nextLevel[i/2] = keccak256(abi.encodePacked(currentLevel[i], currentLevel[i+1]));
                    if (i == currentIndex || i + 1 == currentIndex) {
                        merkleProof[proofIndex++] = currentIndex % 2 == 0 ? currentLevel[i+1] : currentLevel[i];
                    }
                } else {
                    nextLevel[i/2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
            currentIndex /= 2;
        }
        
        return merkleProof;
    }

    /// @notice 生成模拟的零知识证明
    function _generateProof(uint256[2] memory inputs) private view returns (IRedPacketVerifier.Proof memory) {
        return IRedPacketVerifier.Proof({
            A: BN254.G1Point(inputs[0] % BN254.FP_MODULUS, inputs[1] % BN254.FP_MODULUS),
            B: BN254.G2Point(
                [uint256(1), uint256(2)],
                [uint256(3), uint256(4)]
            ),
            C: BN254.G1Point(uint256(1), uint256(2))
        });
    }
} 