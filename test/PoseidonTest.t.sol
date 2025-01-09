// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "zk-kit/packages/poseidon/contracts/Poseidon.sol";

contract PoseidonTest is Test {
    Poseidon public poseidon;

    function setUp() public {
        poseidon = new Poseidon();
    }

    function testPoseidonHash() public {
        uint256[] memory inputs = new uint256[](3);
        inputs[0] = 1;
        inputs[1] = 2;
        inputs[2] = 3;

        uint256 hash = poseidon.poseidon(inputs);
        assertTrue(hash != 0, "Hash should not be zero");
        
        // 测试相同输入得到相同哈希
        uint256 hash2 = poseidon.poseidon(inputs);
        assertEq(hash, hash2, "Same inputs should produce same hash");
    }
} 