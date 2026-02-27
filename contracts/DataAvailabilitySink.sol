// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal DA sink that records batch data on-chain via calldata.
contract DataAvailabilitySink {
    event DataPublished(bytes32 indexed batchHash, bytes data);

    /// @dev Stores calldata and emits its hash; returns the hash for clients.
    function publishData(bytes calldata data) external returns (bytes32 batchHash) {
        batchHash = keccak256(data);
        emit DataPublished(batchHash, data);
    }
}
