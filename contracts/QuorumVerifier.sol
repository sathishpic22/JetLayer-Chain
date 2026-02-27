// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LLMDeliberativeConsensus.sol";

/// @notice Threshold ECDSA verifier for LLM deliberation attestations.
/// Proof format: concatenated 65-byte ECDSA signatures over the raw inputHash.
/// Signers must be in the authorized set and unique; ordering does not matter.
contract QuorumVerifier is IProofVerifier {
    mapping(address => uint8) public signerIndex; // 1-based index
    address public governor;
    uint256 public threshold;
    uint256 public signerCount;
    address[] public signerSet;

    event SignerSetUpdated(address[] signers, uint256 threshold);
    event GovernorUpdated(address indexed oldGovernor, address indexed newGovernor);

    error NotGovernor();
    error BadThreshold();

    constructor(address[] memory signers, uint256 _threshold, address governor_) {
        _setSignerSet(signers, _threshold);
        governor = governor_;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert NotGovernor();
        _;
    }

    function setGovernor(address newGovernor) external onlyGovernor {
        emit GovernorUpdated(governor, newGovernor);
        governor = newGovernor;
    }

    function updateSignerSet(address[] memory signers, uint256 _threshold) external onlyGovernor {
        _setSignerSet(signers, _threshold);
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

    function _setSignerSet(address[] memory signers, uint256 _threshold) internal {
        if (signers.length == 0) revert BadThreshold();
        if (_threshold == 0 || _threshold > signers.length) revert BadThreshold();

        // Clear old index mapping
        for (uint256 i = 0; i < signerSet.length; i++) {
            delete signerIndex[signerSet[i]];
        }

        signerSet = signers;
        threshold = _threshold;
        signerCount = signers.length;

        for (uint256 i = 0; i < signers.length; i++) {
            address s = signers[i];
            require(s != address(0), "zero signer");
            require(signerIndex[s] == 0, "duplicate signer");
            signerIndex[s] = uint8(i + 1);
        }

        emit SignerSetUpdated(signers, _threshold);
    }
}
