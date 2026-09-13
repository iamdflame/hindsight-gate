# hindsight-gate

A ~50-line contract that asks Ethereum questions on Creditcoin **without ever calling the block-prover
precompile** — by consuming [Hindsight](https://github.com/iamdflame/HINDSIGHT)'s published interfaces
and nothing else.

| | |
|---|---|
| `Gate` on Creditcoin CC3 testnet | [`0xeeFa14CA77cEe451Df6474c9dCcBce38A691a254`](https://creditcoin-testnet.blockscout.com/address/0xeeFa14CA77cEe451Df6474c9dCcBce38A691a254) (verified) |
| Deployed by | `0x7fE23D93bDA4780e0596D7e64E7C54088d48BE85` — a fresh address, not Hindsight's deployer |
| Reads | `IMirror` at `0x2d8A…c118`, `IAbsenceV3` at `0x0584…8e40` |
| Earlier deployment | `0x2363930C993cbF3449997cDCdF85007F9041F9dB` read Hindsight's first v3 registry (`0xf0a2…Cc17`), replaced before any claim was filed on it because it had no per-subject index. It still works; it reads an empty board. |

## Honest provenance

This repository has the same GitHub owner as Hindsight. It is not a third party's integration, and
does not claim to be. What it demonstrates is narrower and still worth checking: the interfaces are
enough. `src/IMirror.sol`, `src/IAbsence.sol` and `src/IAbsenceV3.sol` are copied byte-for-byte from
the Hindsight repository; nothing else is imported, and Hindsight's storage and ABI did not change to
accommodate this contract.

## What it does

```solidity
// Did this Ethereum transaction happen? Reverts if not. Returns its position in the block.
function happened(uint64 height, bytes calldata txBytes, MerkleProofEntry[] calldata path)
    external view returns (uint64 position);

// Would I rely on this absence claim for `exposure`? Only if a liar would have lost at least that much.
function wouldRely(uint256 claimId, uint256 exposure) external view returns (bool);

// Has anyone proven, against a held root, that `subject` emitted this event at or above `sinceHeight`?
// One read of the registry's per-subject index, however many claims exist.
function provenSince(address venue, bytes32 topic0, uint8 slot, address subject, uint64 sinceHeight)
    external view returns (bool);
```

Your contract never calls `0x0FD2`. The mirror already holds the root the precompile certified once;
`happened` is a Merkle path against it.

## Check it yourself

```bash
forge test -vv
```

The tests fork live Creditcoin CC3 state — the real mirror and registry, no mocks of either — verify a
real Aave V3 liquidation from Ethereum mainnet, then **delete the precompile on the fork** with
`vm.etch(0x0FD2, "")` and verify it again.

Or against the deployed contract, with the precompile deleted by an `eth_call` state override:

```bash
curl -s https://rpc.cc3-testnet.creditcoin.network -H 'content-type: application/json' -d '{
  "jsonrpc":"2.0","id":1,"method":"eth_call",
  "params":[{"to":"0xeeFa14CA77cEe451Df6474c9dCcBce38A691a254","data":"<happened(...) calldata>"},
            "latest",
            {"0x0000000000000000000000000000000000000FD2":{"code":"0x"}}]}'
```

Measured against the current deployment: the call returns position `263` for
`0x3a4b8bcf…10df61` (block 25,954,574) as a plain call and with `0x0FD2` blanked. With the *mirror*
blanked instead, the same call reverts — the control that shows the node honours the override.

MIT.
