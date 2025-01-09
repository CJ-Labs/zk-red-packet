# 智能红包系统

一个基于区块链的智能红包系统，使用零知识证明实现隐私保护。

## 系统概述

本系统实现了类似微信红包的功能，通过零知识证明(ZK Proof)和Merkle树实现隐私保护和防重复领取。

### 核心功能

1. **发红包功能**
   - 固定金额模式：每个红包金额相同
   - 随机金额模式：系统随机分配金额

2. **抢红包功能**
   - 基于零知识证明验证用户身份
   - 使用Merkle树防止重复领取
   - 支持密码验证
   - 先到先得机制

### 技术特点
- 使用Poseidon哈希保护用户隐私
- 采用Merkle树优化存储
- 支持零知识证明验证
- 完整的防重入保护

## 开发环境

### 依赖
- Foundry - 智能合约开发框架
- zk-kit - 零知识证明工具包
- OpenZeppelin - 智能合约库

### 安装

1. 安装 Foundry:
```shell
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. 克隆仓库:
```shell
git clone <repository_url>
cd <repository_name>
```

3. 安装依赖:
```shell
forge install
```

## 使用说明

### 构建

```shell
forge build
```

### 测试

```shell
forge test
```

### 部署

1. 设置环境变量:
```shell
export PRIVATE_KEY=<your_private_key>
```

2. 运行部署脚本:
```shell
forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --broadcast
```

## 合约架构

### 主要合约

1. **RedPacket.sol**
   - 处理红包的创建和领取
   - 实现防重入保护
   - 集成零知识证明验证

2. **RedPacketVerifier.sol**
   - 验证零知识证明
   - 集成 Groth16 验证系统

3. **Poseidon.sol** (from zk-kit)
   - 提供 Poseidon 哈希功能
   - 用于生成隐私保护的哈希值

### 接口

1. **IRedPacketVerifier.sol**
   - 定义验证器接口
   - 支持 Groth16 证明系统

2. **IPoseidon.sol**
   - 定义 Poseidon 哈希接口
   - 提供哈希计算功能

## 开发工具

Foundry 工具集:

-   **Forge**: Ethereum 测试框架
-   **Cast**: 与 EVM 智能合约交互的工具
-   **Anvil**: 本地以太坊节点
-   **Chisel**: Solidity REPL

### 常用命令

```shell
# 格式化代码
$ forge fmt

# 生成 Gas 报告
$ forge snapshot

# 启动本地节点
$ anvil

# 获取帮助
$ forge --help
$ anvil --help
$ cast --help
```

## 安全考虑

1. **隐私保护**
   - 使用 Poseidon 哈希保护用户信息
   - 零知识证明验证身份

2. **防重入保护**
   - 使用 OpenZeppelin 的 ReentrancyGuard
   - 严格的状态管理

3. **随机数安全**
   - 使用区块信息作为随机源
   - 确保公平性

## 文档

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/)
- [zk-kit Documentation](https://github.com/privacy-scaling-explorations/zk-kit)

## 测试

1. **单元测试**
   ```shell
   forge test
   ```

2. **特定测试**
   ```shell
   forge test --match-test testPoseidonHash
   ```

3. **测试覆盖率**
   ```shell
   forge coverage
   ```

## 贡献指南

1. Fork 项目
2. 创建特性分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

MIT
