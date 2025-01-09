// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/RedPacket.sol";
import "../src/RedPacketVerifier.sol";
import "zk-kit/packages/poseidon/contracts/Poseidon.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 Poseidon
        Poseidon poseidon = new Poseidon();
        console.log("Poseidon deployed at:", address(poseidon));

        // 2. 部署验证器
        RedPacketVerifier.VerifyingKey memory vk;  // 这里需要设置实际的验证密钥
        RedPacketVerifier verifier = new RedPacketVerifier(vk);
        console.log("Verifier deployed at:", address(verifier));

        // 3. 部署红包合约
        RedPacket redPacket = new RedPacket(
            address(verifier),
            address(poseidon)
        );
        console.log("RedPacket deployed at:", address(redPacket));

        vm.stopBroadcast();
    }
} 