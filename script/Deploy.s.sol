// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/QuorumVerifier.sol";
import "../contracts/LLMDeliberativeConsensus.sol";

/// @notice Foundry deploy script for QuorumVerifier and LLMDeliberativeConsensus.
/// Edit the signer addresses, threshold, and minStake before running.
contract Deploy is Script {
    // --- configure here ---
    address[] internal signers;
    uint256 internal threshold = 2;
    uint256 internal minStake = 0.1 ether;
    uint64 internal challengeWindowSeconds = 1 days;
    uint64 internal epochSpanBlocks = 100;
    address internal governor;

    function setUp() public {
        // Example signer set; replace with your actual operator keys.
        signers = new address[](3);
        signers[0] = 0x000000000000000000000000000000000000dEaD;
        signers[1] = 0x000000000000000000000000000000000000bEEF;
        signers[2] = 0x000000000000000000000000000000000000c0Fe;

        governor = msg.sender;
    }

    function run() public {
        vm.startBroadcast();

        QuorumVerifier quorum = new QuorumVerifier(signers, threshold, governor);
        LLMDeliberativeConsensus consensus = new LLMDeliberativeConsensus(
            IProofVerifier(address(quorum)),
            minStake,
            challengeWindowSeconds,
            epochSpanBlocks,
            governor
        );

        console2.log("QuorumVerifier", address(quorum));
        console2.log("LLMDeliberativeConsensus", address(consensus));

        vm.stopBroadcast();
    }
}
