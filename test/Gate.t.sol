// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {INativeQueryVerifier} from "@gluwa/asc-contracts/contracts/write-ability/common/INativeQueryVerifier.sol";
import {Gate} from "../src/Gate.sol";
import {IMirror} from "../src/IMirror.sol";
import {IAbsence} from "../src/IAbsence.sol";
import {IAbsenceV3} from "../src/IAbsenceV3.sol";

/// @notice Runs against live Creditcoin CC3 testnet state: the real Hindsight mirror and registry,
///         forked. No mocks of Hindsight exist in this repository.
contract GateTest is Test {
    IMirror constant MIRROR = IMirror(0x2d8A4d5A34120FF9742d7a4dad37F4ff6335c118);
    IAbsenceV3 constant ABSENCE = IAbsenceV3(0x05844C991993F3d80fAf196e10355B12BE648e40);

    Gate internal gate;
    uint64 internal height;
    uint64 internal index;
    bytes internal txBytes;
    INativeQueryVerifier.MerkleProofEntry[] internal path;

    function setUp() public {
        vm.createSelectFork("creditcoin");
        // Creditcoin's Substrate EVM leaves prevrandao unset in its headers, and revm refuses to
        // execute a creation against such a header. The value is irrelevant to anything tested.
        vm.prevrandao(bytes32(uint256(1)));
        gate = new Gate(MIRROR, ABSENCE);

        // A real Aave V3 liquidation on Ethereum mainnet.
        string memory json = vm.readFile("test/fixtures/liquidation.json");
        height = uint64(vm.parseJsonUint(json, ".headerNumber"));
        index = uint64(vm.parseJsonUint(json, ".txIndex"));
        txBytes = vm.parseJsonBytes(json, ".txBytes");
        bytes32[] memory h = vm.parseJsonBytes32Array(json, ".siblingHashes");
        bool[] memory l = vm.parseJsonBoolArray(json, ".siblingIsLeft");
        for (uint256 i; i < h.length; ++i) path.push(INativeQueryVerifier.MerkleProofEntry({hash: h[i], isLeft: l[i]}));
    }

    function test_theBlockIsHeldByTheLiveMirror() public view {
        assertTrue(MIRROR.isMirrored(3, height), "Hindsight should hold this block");
    }

    function test_happenedVerifiesARealMainnetTransaction() public view {
        assertEq(gate.happened(height, txBytes, path), index);
    }

    /// The claim in this repository's README, run: delete the block-prover precompile and ask again.
    function test_happenedNeverCallsThePrecompile() public {
        vm.etch(address(uint160(0x0FD2)), hex"");
        assertEq(address(uint160(0x0FD2)).code.length, 0);
        assertEq(gate.happened(height, txBytes, path), index);
    }

    function test_aForgedPathReverts() public {
        path[0].hash = bytes32(uint256(path[0].hash) ^ 1);
        vm.expectRevert();
        gate.happened(height, txBytes, path);
    }

    /// The registry's per-subject index, read from outside: an address nobody has filed about has an
    /// empty file, and `provenSince` says nothing has been proven about it.
    function test_anUnfiledAddressHasAnEmptyFile() public view {
        address aave = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        bytes32 liquidationCall = 0xe413a321e8681d831f4dbccbca790d2952b56f977908e45be37335533e005286;
        bytes32 empty = ABSENCE.keyOf(3, aave, liquidationCall, 3, bytes32(uint256(uint160(address(this)))));
        (uint32 open, uint32 refuted, uint64 ev, uint64 mem, uint32 total) = ABSENCE.recordOf(empty);
        assertEq(uint256(open) + refuted + ev + mem + total, 0);
        assertFalse(gate.provenSince(aave, liquidationCall, 3, address(this), 0));
    }

    function test_wouldRelyReadsTheLiveRegistry() public {
        uint256 n = IAbsence(address(ABSENCE)).claimCount();
        if (n == 0) {
            vm.expectRevert();
            gate.wouldRely(0, 1);
            return;
        }
        for (uint256 id; id < n && id < 8; ++id) {
            bool usable = gate.wouldRely(id, 0);
            assertEq(usable, IAbsence(address(ABSENCE)).holds(id), "usable at zero exposure iff the claim stands");
        }
    }
}
