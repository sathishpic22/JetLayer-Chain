// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface for a proof verifier (zk-SNARK, signature quorum, TEE attestation, etc.).
interface IProofVerifier {
    function verify(bytes calldata proof, bytes32 inputHash) external view returns (bool);
}

/// @notice Prototype contract that gates block proposals behind an LLM-backed proof.
contract LLMDeliberativeConsensus {
    struct Proposal {
        bytes32 proposalHash;
        address proposer;
        uint256 stake;
        bool finalized;
        bytes32 decision;
    }

    IProofVerifier public immutable verifier;
    uint256 public immutable minStake;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;

    event ProposalSubmitted(uint256 indexed id, address indexed proposer, bytes32 proposalHash, uint256 stake);
    event ProposalFinalized(uint256 indexed id, bytes32 decision);

    error StakeTooLow();
    error UnknownProposal();
    error AlreadyFinalized();
    error NotFinalized();
    error InvalidProof();

    constructor(IProofVerifier _verifier, uint256 _minStake) {
        verifier = _verifier;
        minStake = _minStake;
    }

    /// @dev Proposer posts a block/tx batch commitment with stake.
    function submitProposal(bytes32 proposalHash) external payable returns (uint256 id) {
        if (msg.value < minStake) revert StakeTooLow();
        id = ++proposalCount;
        proposals[id] = Proposal({
            proposalHash: proposalHash,
            proposer: msg.sender,
            stake: msg.value,
            finalized: false,
            decision: bytes32(0)
        });
        emit ProposalSubmitted(id, msg.sender, proposalHash, msg.value);
    }

    /// @dev LLM decision + proof are provided; proof verifier decides acceptability.
    function finalizeProposal(uint256 id, bytes32 decision, bytes calldata proof) external {
        Proposal storage p = proposals[id];
        if (p.proposer == address(0)) revert UnknownProposal();
        if (p.finalized) revert AlreadyFinalized();

        // Input to the verifier binds proposal, decision, and proposer to prevent replay.
        bytes32 inputHash = keccak256(abi.encodePacked(p.proposalHash, decision, p.proposer));
        if (!verifier.verify(proof, inputHash)) revert InvalidProof();

        p.finalized = true;
        p.decision = decision;

        emit ProposalFinalized(id, decision);
    }

    /// @dev Simple stake withdrawal once finalized; extend with slashing logic as needed.
    function withdrawStake(uint256 id, address payable to) external {
        Proposal storage p = proposals[id];
        if (p.proposer == address(0)) revert UnknownProposal();
        if (!p.finalized) revert NotFinalized();
        require(msg.sender == p.proposer, "not proposer");

        uint256 amount = p.stake;
        p.stake = 0;
        to.transfer(amount);
    }
}
