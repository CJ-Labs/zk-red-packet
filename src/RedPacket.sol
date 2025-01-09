// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRedPacketVerifier.sol";
import "./libraries/Poseidon.sol";

contract RedPacket is ReentrancyGuard, Pausable, Ownable {
    // 红包状态
    enum Status { PENDING, ACTIVE, FINISHED, EXPIRED }
    
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
        uint256 createdAt;   // 创建时间
        uint256 expiresAt;   // 过期时间
    }
    
    // 存储所有红包
    mapping(uint256 => Packet) public packets;
    uint256 public packetCounter;
    
    // 验证器合约
    IRedPacketVerifier public immutable verifier;
    Poseidon public immutable poseidon;
    
    // 常量
    uint256 public constant MAX_COUNT = 100;        // 最大红包数量
    uint256 public constant MIN_AMOUNT = 1e15;      // 最小金额 (0.001 ETH)
    uint256 public constant MAX_DURATION = 7 days;  // 最长有效期
    
    // 事件
    event PacketCreated(
        uint256 indexed packetId,
        address indexed creator,
        uint256 amount,
        uint256 count,
        PacketType packetType
    );
    event PacketClaimed(
        uint256 indexed packetId,
        address indexed claimer,
        uint256 amount
    );
    event PacketExpired(uint256 indexed packetId, uint256 remainingAmount);
    event PacketRefunded(uint256 indexed packetId, uint256 amount);
    
    constructor(
        address _verifier,
        address _poseidon
    ) Ownable(msg.sender) {
        require(_verifier != address(0), "Invalid verifier");
        require(_poseidon != address(0), "Invalid poseidon");
        verifier = IRedPacketVerifier(_verifier);
        poseidon = Poseidon(_poseidon);
    }
    
    // 创建固定金额红包
    function createFixedPacket(
        uint256 count,
        uint256 amountPerPacket,
        bytes32 merkleRoot,
        uint256 duration
    ) external payable whenNotPaused returns (uint256) {
        require(count > 0 && count <= MAX_COUNT, "Invalid count");
        require(amountPerPacket >= MIN_AMOUNT, "Amount too small");
        require(duration > 0 && duration <= MAX_DURATION, "Invalid duration");
        require(msg.value == count * amountPerPacket, "Invalid total amount");
        
        return _createPacket(
            PacketType.FIXED,
            count,
            msg.value,
            merkleRoot,
            duration
        );
    }
    
    // 创建随机金额红包
    function createRandomPacket(
        uint256 count,
        bytes32 merkleRoot,
        uint256 duration
    ) external payable whenNotPaused returns (uint256) {
        require(count > 0 && count <= MAX_COUNT, "Invalid count");
        require(msg.value >= count * MIN_AMOUNT, "Amount too small");
        require(duration > 0 && duration <= MAX_DURATION, "Invalid duration");
        
        return _createPacket(
            PacketType.RANDOM,
            count,
            msg.value,
            merkleRoot,
            duration
        );
    }
    
    // 内部创建红包函数
    function _createPacket(
        PacketType packetType,
        uint256 count,
        uint256 totalAmount,
        bytes32 merkleRoot,
        uint256 duration
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
            merkleRoot: merkleRoot,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + duration
        });
        
        emit PacketCreated(
            packetId,
            msg.sender,
            totalAmount,
            count,
            packetType
        );
        
        return packetId;
    }
    
    // 领取红包
    function claimPacket(
        uint256 packetId,
        bytes32[] calldata merkleProof,
        IRedPacketVerifier.Proof calldata zkProof,
        string calldata password
    ) external nonReentrant whenNotPaused {
        Packet storage packet = packets[packetId];
        require(packet.status == Status.ACTIVE, "Packet not active");
        require(packet.remainingCount > 0, "Packet empty");
        require(block.timestamp < packet.expiresAt, "Packet expired");
        
        // 使用 Poseidon 计算密码哈希
        uint256[2] memory inputs;
        inputs[0] = uint256(uint160(msg.sender));
        inputs[1] = uint256(keccak256(abi.encodePacked(password, packetId)));
        
        uint256 poseidonHash = poseidon.hash(inputs);
        
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
    function _calculateClaimAmount(
        Packet storage packet
    ) internal view returns (uint256) {
        if (packet.packetType == PacketType.FIXED) {
            return packet.totalAmount / packet.count;
        }
        
        uint256 remaining = packet.remainingAmount;
        uint256 count = packet.remainingCount;
        
        if (count == 1) {
            return remaining;
        }
        
        // 使用更安全的随机数生成方式
        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    packet.creator,
                    packet.createdAt
                )
            )
        );
        
        // 确保每个人至少能获得最小金额
        uint256 minAmount = MIN_AMOUNT;
        uint256 maxAmount = remaining - (count - 1) * minAmount;
        
        return minAmount + (rand % (maxAmount - minAmount + 1));
    }
    
    // 过期红包退回
    function refundExpiredPacket(
        uint256 packetId
    ) external nonReentrant {
        Packet storage packet = packets[packetId];
        require(packet.status == Status.ACTIVE, "Packet not active");
        require(block.timestamp >= packet.expiresAt, "Packet not expired");
        require(msg.sender == packet.creator, "Not creator");
        
        uint256 remainingAmount = packet.remainingAmount;
        packet.remainingAmount = 0;
        packet.status = Status.EXPIRED;
        
        (bool success, ) = packet.creator.call{value: remainingAmount}("");
        require(success, "Transfer failed");
        
        emit PacketExpired(packetId, remainingAmount);
    }
    
    // 紧急暂停
    function pause() external onlyOwner {
        _pause();
    }
    
    // 恢复
    function unpause() external onlyOwner {
        _unpause();
    }
} 