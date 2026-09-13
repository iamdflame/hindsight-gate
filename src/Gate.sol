// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {INativeQueryVerifier} from "@gluwa/asc-contracts/contracts/write-ability/common/INativeQueryVerifier.sol";
import {IMirror} from "./IMirror.sol";
import {IAbsenceV3} from "./IAbsenceV3.sol";

/// @title Gate
/// @notice A consumer of Hindsight written against its published interfaces and nothing else.
/// @dev This contract never calls 0x0FD2. It asks the mirror, which already holds the root.
contract Gate {
    uint64 public constant ETHEREUM = 3;
    IMirror public immutable MIRROR;
    IAbsenceV3 public immutable ABSENCE;

    constructor(IMirror mirror, IAbsenceV3 absence) {
        MIRROR = mirror;
        ABSENCE = absence;
    }

    /// @notice Did this Ethereum transaction happen? Reverts if not. Returns its position in the block.
    function happened(uint64 height, bytes calldata txBytes, INativeQueryVerifier.MerkleProofEntry[] calldata path)
        external
        view
        returns (uint64 position)
    {
        return MIRROR.verifyOrRevert(ETHEREUM, height, txBytes, path);
    }

    /// @notice Would I rely on this claim for `exposure`? Only if a liar would have lost at least that much.
    function wouldRely(uint256 claimId, uint256 exposure) external view returns (bool) {
        return ABSENCE.isUsable(claimId, exposure);
    }

    /// @notice Has anyone proven, against a held root, that `subject` emitted this event at `venue`
    ///         at or above `sinceHeight`? One read of the registry's index, however big the board is.
    function provenSince(address venue, bytes32 topic0, uint8 slot, address subject, uint64 sinceHeight)
        external
        view
        returns (bool)
    {
        bytes32 key = ABSENCE.keyOf(ETHEREUM, venue, topic0, slot, bytes32(uint256(uint160(subject))));
        (, uint32 refuted, uint64 lastEvidenceAt, uint64 lastMemberAt,) = ABSENCE.recordOf(key);
        return (refuted != 0 && lastEvidenceAt >= sinceHeight) || (lastMemberAt != 0 && lastMemberAt >= sinceHeight);
    }
}
