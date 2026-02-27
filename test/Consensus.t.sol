// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/QuorumVerifier.sol";
import "../contracts/LLMDeliberativeConsensus.sol";

contract ConsensusTest is Test {
    QuorumVerifier verifier;
    LLMDeliberativeConsensus consensus;

    address signer1 = vm.addr(1);
    address signer2 = vm.addr(2);
    address signer3 = vm.addr(3);
    uint256 pk1 = 1;
    uint256 pk2 = 2;
    uint256 pk3 = 3;

    function setUp() public {
        address[] memory signers = new address[](3);
        signers[0] = signer1;
        signers[1] = signer2;
        signers[2] = signer3;
        verifier = new QuorumVerifier(signers, 2, address(this));
        consensus = new LLMDeliberativeConsensus(verifier, 0.1 ether, 1 days, 100, address(this));
    }

    function _sign(bytes32 digest, uint256 pk) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory sig = new bytes(65);
        assembly {
            mstore(add(sig, 32), r)
            mstore(add(sig, 64), s)
            mstore8(add(sig, 96), v)
        }
        return sig;
    }

    function _concat(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        return bytes.concat(a, b);
    }

    function testFinalizeWithQuorum() public {
        uint256 id = consensus.submitProposal{value: 0.1 ether}(keccak256("batch1"));
        uint64 epoch = consensus.currentEpoch();
        bytes32 inputHash = keccak256(abi.encodePacked(keccak256("batch1"), bytes32(uint256(123)), address(this), epoch));

        bytes memory proof = _concat(_sign(inputHash, pk1), _sign(inputHash, pk2));
        consensus.finalizeProposal(id, bytes32(uint256(123)), proof);

        (,,,,,, , , bytes32 decision) = consensus.proposals(id);
        assertEq(decision, bytes32(uint256(123)));
    }

    function testFinalizeFailsWithBadSig() public {
        uint256 id = consensus.submitProposal{value: 0.1 ether}(keccak256("batch1"));
        uint64 epoch = consensus.currentEpoch();
        bytes32 inputHash = keccak256(abi.encodePacked(keccak256("batch1"), bytes32(uint256(123)), address(this), epoch));
        bytes32 wrongHash = keccak256(abi.encodePacked(keccak256("batch1"), bytes32(uint256(321)), address(this), epoch));

        bytes memory proof = _concat(_sign(wrongHash, pk1), _sign(wrongHash, pk2));
        vm.expectRevert(LLMDeliberativeConsensus.InvalidProof.selector);
        consensus.finalizeProposal(id, bytes32(uint256(123)), proof);
    }

    function testDuplicateSignaturesDoNotCountTwice() public {
        uint256 id = consensus.submitProposal{value: 0.1 ether}(keccak256("batch1"));
        uint64 epoch = consensus.currentEpoch();
        bytes32 inputHash = keccak256(abi.encodePacked(keccak256("batch1"), bytes32(uint256(123)), address(this), epoch));

        // Only signer1 signs, duplicated twice
        bytes memory proof = _concat(_sign(inputHash, pk1), _sign(inputHash, pk1));
        vm.expectRevert(LLMDeliberativeConsensus.InvalidProof.selector);
        consensus.finalizeProposal(id, bytes32(uint256(123)), proof);
    }
}
