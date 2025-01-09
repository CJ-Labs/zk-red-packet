// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPoseidon {
    function poseidon(uint256[] calldata inputs) external pure returns (uint256);
} 