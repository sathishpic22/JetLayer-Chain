// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LLMDeliberativeConsensus.sol";

/// @notice Demo verifier that unconditionally accepts proofs; replace with real zk or signature verification.
contract MockVerifier is IProofVerifier {
    function verify(bytes calldata, bytes32) external pure override returns (bool) {
        return true;
    }
}
