// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LLMDeliberativeConsensus.sol";

/// @notice Threshold ECDSA verifier for LLM deliberation attestations.
/// Proof format: concatenated 65-byte ECDSA signatures over the raw inputHash.
/// Signers must be in the authorized set and unique; ordering does not matter.
contract QuorumVerifier is IProofVerifier {
    mapping(address => uint8) public signerIndex; // 1-based index
    uint256 public immutable threshold;
    uint256 public immutable signerCount;

    constructor(address[] memory signers, uint256 _threshold) {
        require(signers.length > 0, "no signers");
        require(_threshold > 0 && _threshold <= signers.length, "bad threshold");
        threshold = _threshold;
        signerCount = signers.length;
        for (uint256 i = 0; i < signers.length; i++) {
            address s = signers[i];
            require(s != address(0), "zero signer");
            require(signerIndex[s] == 0, "duplicate signer");
            signerIndex[s] = uint8(i + 1);
        }
    }

    /// @dev Verifies that at least `threshold` unique authorized signers signed `inputHash`.
    function verify(bytes calldata proof, bytes32 inputHash) external view override returns (bool) {
        if (proof.length % 65 != 0) return false;
        uint256 sigCount = proof.length / 65;
        if (sigCount == 0) return false;

        uint256 seenBitmap;
        uint256 approvals;

        for (uint256 offset = 0; offset < proof.length; offset += 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := calldataload(add(proof.offset, offset))
                s := calldataload(add(add(proof.offset, offset), 32))
                v := byte(0, calldataload(add(add(proof.offset, offset), 64)))
            }
            if (v < 27) v += 27;
            address signer = ecrecover(inputHash, v, r, s);
            if (signer == address(0)) continue;
            uint256 idx = signerIndex[signer];
            if (idx == 0) continue;
            uint256 mask = 1 << (idx - 1);
            if (seenBitmap & mask != 0) continue;
            seenBitmap |= mask;
            approvals++;
            if (approvals >= threshold) return true;
        }
        return false;
    }
}
