// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IRedPacketVerifier.sol";
import "./interfaces/IPoseidon.sol";

contract RedPacket is ReentrancyGuard {
    // 红包状态
    enum Status { PENDING, ACTIVE, FINISHED }
    
    // 红包类型
    enum PacketType { FIXED, RANDOM }
    
    // 红包结构
    struct Packet {
        address creator;      // 创建者
        uint256 totalAmount; // 总金额
        uint256 remainingAmount; // 剩余金额
        uint256 count;       // 红包数量
        uint256 remainingCount; // 剩余数量
        PacketType packetType; // 红包类型
        Status status;       // 状态
        bytes32 merkleRoot;  // 默克尔树根
    }
    
    // 存储所有红包
    mapping(uint256 => Packet) public packets;
    uint256 public packetCounter;
    
    // 验证器合约
    IRedPacketVerifier public verifier;
    
    // 添加 Poseidon 哈希合约
    IPoseidon public poseidon;
    
    // 事件
    event PacketCreated(uint256 indexed packetId, address creator, uint256 amount, uint256 count);
    event PacketClaimed(uint256 indexed packetId, address claimer, uint256 amount);
    
    constructor(address _verifier, address _poseidon) {
        verifier = IRedPacketVerifier(_verifier);
        poseidon = IPoseidon(_poseidon);
    }
    
    // 创建固定金额红包
    function createFixedPacket(
        uint256 count,
        uint256 amountPerPacket,
        bytes32 merkleRoot
    ) external payable returns (uint256) {
        require(msg.value == count * amountPerPacket, "Invalid total amount");
        return _createPacket(PacketType.FIXED, count, msg.value, merkleRoot);
    }
    
    // 创建随机金额红包
    function createRandomPacket(
        uint256 count,
        bytes32 merkleRoot
    ) external payable returns (uint256) {
        require(msg.value > count, "Amount too small");
        return _createPacket(PacketType.RANDOM, count, msg.value, merkleRoot);
    }
    
    // 内部创建红包函数
    function _createPacket(
        PacketType packetType,
        uint256 count,
        uint256 totalAmount,
        bytes32 merkleRoot
    ) internal returns (uint256) {
        uint256 packetId = ++packetCounter;
        
        packets[packetId] = Packet({
            creator: msg.sender,
            totalAmount: totalAmount,
            remainingAmount: totalAmount,
            count: count,
            remainingCount: count,
            packetType: packetType,
            status: Status.ACTIVE,
            merkleRoot: merkleRoot
        });
        
        emit PacketCreated(packetId, msg.sender, totalAmount, count);
        return packetId;
    }
    
    // 领取红包
    function claimPacket(
        uint256 packetId,
        bytes32[] calldata merkleProof,
        IRedPacketVerifier.Proof calldata zkProof,
        string calldata password
    ) external nonReentrant {
        Packet storage packet = packets[packetId];
        require(packet.status == Status.ACTIVE, "Packet not active");
        require(packet.remainingCount > 0, "Packet empty");
        
        // 使用 Poseidon 计算密码哈希
        uint256[] memory inputs = new uint256[](3);
        inputs[0] = uint256(uint160(msg.sender));
        inputs[1] = uint256(keccak256(abi.encodePacked(password)));
        inputs[2] = packetId;
        
        uint256 poseidonHash = poseidon.poseidon(inputs);
        
        // 验证默克尔证明
        bytes32 leaf = bytes32(poseidonHash);
        require(
            MerkleProof.verify(merkleProof, packet.merkleRoot, leaf),
            "Invalid merkle proof"
        );
        
        // 验证零知识证明
        require(
            verifier.verifyProof(zkProof, [packetId, poseidonHash]),
            "Invalid zk proof"
        );
        
        // 计算领取金额
        uint256 amount = _calculateClaimAmount(packet);
        
        // 更新红包状态
        packet.remainingAmount -= amount;
        packet.remainingCount--;
        
        if (packet.remainingCount == 0) {
            packet.status = Status.FINISHED;
        }
        
        // 转账
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit PacketClaimed(packetId, msg.sender, amount);
    }
    
    // 计算领取金额
    function _calculateClaimAmount(Packet storage packet) internal view returns (uint256) {
        if (packet.packetType == PacketType.FIXED) {
            return packet.totalAmount / packet.count;
        } else {
            // 随机金额算法
            uint256 remaining = packet.remainingAmount;
            uint256 count = packet.remainingCount;
            
            if (count == 1) {
                return remaining;
            }
            
            // 使用区块信息作为随机源
            uint256 rand = uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender
                    )
                )
            );
            
            // 确保每个人至少能获得1wei
            uint256 max = remaining - count + 1;
            return (rand % max) + 1;
        }
    }
} 