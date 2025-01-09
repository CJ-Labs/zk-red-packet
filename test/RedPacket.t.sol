// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RedPacket.sol";
import "../src/RedPacketVerifier.sol";
import "zk-kit/packages/poseidon/contracts/Poseidon.sol";

contract RedPacketTest is Test {
    RedPacket public redPacket;
    RedPacketVerifier public verifier;
    Poseidon public poseidonContract;
    
    address public alice = address(1);
    address public bob = address(2);
    
    function setUp() public {
        // 部署 Poseidon 合约
        poseidonContract = new Poseidon();
        
        // 部署验证器
        RedPacketVerifier.VerifyingKey memory vk;
        verifier = new RedPacketVerifier(vk);
        
        // 部署红包合约
        redPacket = new RedPacket(address(verifier), address(poseidonContract));
        
        // 给测试账户一些ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }
    
    function testCreateAndClaimFixedPacket() public {
        vm.startPrank(alice);
        
        // 创建红包
        uint256 count = 5;
        uint256 amountPerPacket = 1 ether;
        string memory password = "secret";
        
        // 计算 Poseidon 哈希
        uint256[] memory inputs = new uint256[](3);
        inputs[0] = uint256(uint160(bob));
        inputs[1] = uint256(keccak256(abi.encodePacked(password)));
        inputs[2] = 1; // packetId will be 1
        
        uint256 poseidonHash = poseidonContract.poseidon(inputs);
        
        // 创建默克尔树
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = bytes32(poseidonHash);
        bytes32 merkleRoot = leaves[0]; // 简化版本，实际需要构建完整的默克尔树
        
        uint256 packetId = redPacket.createFixedPacket{value: 5 ether}(
            count,
            amountPerPacket,
            merkleRoot
        );
        
        vm.stopPrank();
        
        // Bob 领取红包
        vm.startPrank(bob);
        
        bytes32[] memory proof = new bytes32[](0); // 简化版本的默克尔证明
        IRedPacketVerifier.Proof memory zkProof; // 简化版本的零知识证明
        
        redPacket.claimPacket(
            packetId,
            proof,
            zkProof,
            password
        );
        
        assertEq(bob.balance, 101 ether); // 原有100 ether + 领取的1 ether
        
        vm.stopPrank();
    }
} 