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
        bool challenged;
        bool slashed;
        uint64 epoch;
        uint64 finalizedAt;
        bytes32 decision;
    }

    IProofVerifier public immutable verifier;
    uint256 public immutable minStake;
    uint64 public immutable challengeWindowSeconds;
    uint64 public immutable epochSpanBlocks;
    address public governor;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;

    event ProposalSubmitted(uint256 indexed id, address indexed proposer, bytes32 proposalHash, uint256 stake);
    event ProposalFinalized(uint256 indexed id, bytes32 decision);
    event ProposalChallenged(uint256 indexed id, address indexed challenger);
    event ProposalSlashed(uint256 indexed id, address indexed recipient, uint256 amount);
    event GovernorUpdated(address indexed oldGovernor, address indexed newGovernor);

    error StakeTooLow();
    error UnknownProposal();
    error AlreadyFinalized();
    error NotFinalized();
    error InvalidProof();
    error ChallengeWindowNotElapsed();
    error NotProposer();
    error AlreadyChallenged();
    error Slashed();
    error NotGovernor();
    error EpochMismatch();
    error NotChallenged();
    error InvalidEpochSpan();
    error InvalidChallengeWindow();

    constructor(IProofVerifier _verifier, uint256 _minStake, uint64 _challengeWindowSeconds, uint64 _epochSpanBlocks, address _governor) {
        verifier = _verifier;
        minStake = _minStake;
        if (_challengeWindowSeconds == 0) revert InvalidChallengeWindow();
        if (_epochSpanBlocks == 0) revert InvalidEpochSpan();
        challengeWindowSeconds = _challengeWindowSeconds;
        epochSpanBlocks = _epochSpanBlocks;
        governor = _governor;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert NotGovernor();
        _;
    }

    function currentEpoch() public view returns (uint64) {
        return uint64(block.number / epochSpanBlocks);
    }

    function setGovernor(address newGovernor) external onlyGovernor {
        emit GovernorUpdated(governor, newGovernor);
        governor = newGovernor;
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
            challenged: false,
            slashed: false,
            epoch: currentEpoch(),
            finalizedAt: 0,
            decision: bytes32(0)
        });
        emit ProposalSubmitted(id, msg.sender, proposalHash, msg.value);
    }

    /// @dev LLM decision + proof are provided; proof verifier decides acceptability.
    function finalizeProposal(uint256 id, bytes32 decision, bytes calldata proof) external {
        Proposal storage p = proposals[id];
        if (p.proposer == address(0)) revert UnknownProposal();
        if (p.finalized) revert AlreadyFinalized();
        if (currentEpoch() != p.epoch) revert EpochMismatch();

        // Input to the verifier binds proposal, decision, and proposer to prevent replay.
        bytes32 inputHash = keccak256(abi.encodePacked(p.proposalHash, decision, p.proposer, p.epoch));
        if (!verifier.verify(proof, inputHash)) revert InvalidProof();

        p.finalized = true;
        p.decision = decision;
        p.finalizedAt = uint64(block.timestamp);

        emit ProposalFinalized(id, decision);
    }

    /// @dev Anyone can flag a finalized proposal during the challenge window.
    function raiseChallenge(uint256 id) external {
        Proposal storage p = proposals[id];
        if (p.proposer == address(0)) revert UnknownProposal();
        if (!p.finalized) revert NotFinalized();
        if (p.slashed) revert Slashed();
        if (p.challenged) revert AlreadyChallenged();
        p.challenged = true;
        emit ProposalChallenged(id, msg.sender);
    }

    /// @dev Governor can slash a challenged proposal and redirect stake.
    function slash(uint256 id, address payable recipient) external onlyGovernor {
        Proposal storage p = proposals[id];
        if (p.proposer == address(0)) revert UnknownProposal();
        if (!p.finalized) revert NotFinalized();
        if (!p.challenged) revert NotChallenged();
        if (p.slashed) revert Slashed();

        p.slashed = true;
        uint256 amount = p.stake;
        p.stake = 0;
        address payable to = recipient == address(0) ? payable(governor) : recipient;
        if (amount > 0) to.transfer(amount);
        emit ProposalSlashed(id, to, amount);
    }

    /// @dev Simple stake withdrawal once finalized; extend with slashing logic as needed.
    function withdrawStake(uint256 id, address payable to) external {
        Proposal storage p = proposals[id];
        if (p.proposer == address(0)) revert UnknownProposal();
        if (!p.finalized) revert NotFinalized();
        if (p.slashed) revert Slashed();
        if (block.timestamp < p.finalizedAt + challengeWindowSeconds) revert ChallengeWindowNotElapsed();
        if (msg.sender != p.proposer) revert NotProposer();

        uint256 amount = p.stake;
        p.stake = 0;
        to.transfer(amount);
    }
}
