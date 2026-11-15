# 1Claw Blockchain Council

A multi-agent smart-contract pentest harness. A council of LLM agents argues about whether a contract is vulnerable — but **the argument never decides**. A finding is only accepted when an exploit, signed with a key that lives in [1Claw](https://1claw.co), actually moves ETH out of the target on a local chain and reproduces on a clean replay.

```
            ┌──────────── Auditor (sonnet) ── proposes hypotheses
 target ──► │                 ▲   │
 source     │        rebuttal │   ▼ challenge
 (1Claw     │             Skeptic (opus) ── pursue / reject   ──► rejected_in_debate
 inspect)   │                     │ pursue
            │                     ▼
            │             Exploiter (sonnet) ── writes Exploit.sol  ◄─┐ compile errors /
            │                     │                                   │ on-chain result
            │                     ▼                                   │ (≤3 attempts)
            └──────────── On-chain oracle ──────────────────────────┘ ──► refuted
                          real txs from unprivileged EOA, key fetched from 1Claw,
                          chain 31337 only. Profit = attacker Δ>0 (net of gas) AND target Δ<0
                                  │ profit
                                  ▼
                          clean-snapshot replay + Skeptic review ──► confirmed / disputed
```

## Why on-chain makes the council honest

- **No cheating.** LLM-written Foundry PoCs love `vm.prank(owner)`, `vm.store`, `deal()`. Here the PoC is deployed and called as *real signed transactions* from an unprivileged EOA, so cheatcodes don't exist. Either the attacker's balance goes up or it doesn't.
- **Different model for the Skeptic** (opus vs sonnet) so its blind spots aren't the Auditor's.
- **Debate is cheap filtering, the chain is the judge.** The Skeptic can kill a hypothesis in debate, but a hypothesis that survives still has to produce profit.

## What 1Claw does here

| 1Claw feature | Use |
|---|---|
| Vault (`secrets.get/set`) | The attacker private key is generated on first run and stored in 1Claw. It is fetched at the moment of each signature with an audit `reason` (`"sign PoC attack() on fork 31337: EtherBank/H1/attempt-2"`), never written to disk or shown to an agent. |
| `inspectContent` | Every target source is scanned before it reaches an agent. |
| Agent token scopes | The harness can only touch secret paths the 1Claw agent is scoped to. |

The **fork-only boundary** is enforced in code: `attackerWallet()` refuses to sign unless the RPC is localhost *and* `chainId == 31337` (anvil is started with `--chain-id 31337` explicitly — a forked anvil otherwise keeps the mainnet chain id).

## Run it

Requires [Bun](https://bun.sh), [Foundry](https://getfoundry.sh) (`forge`, `anvil` in `~/.foundry/bin`), the [Claude Code CLI](https://claude.com/claude-code) logged in (agents run via `claude -p`), and a 1Claw agent API key.

```sh
bun install
export ONECLAW_AGENT_API_KEY=ocv_...
# optional: ONECLAW_VAULT_ID (defaults to the agent's first vault)
#           ONECLAW_KEY_PATH (default examples/pentest/attacker-key — must be inside the agent's token scopes)
bun council.ts              # all contracts in targets/
bun council.ts EtherBank    # one target
```

Each target gets its own anvil instance and runs in parallel. Output:
- live colored transcript of the council in the terminal
- `reports/<run>/report.md` and `findings.json` (full debate transcript, tx hashes, balance deltas)
- `exploits/<run>/<target>/<hypothesis>/attempt-N/Exploit.sol` — every PoC attempt

## Lab targets

| Contract | Ground truth |
|---|---|
| `EtherBank.sol` | Reentrancy: `withdraw()` pays before zeroing the balance |
| `Treasury.sol` | Unprotected `initialize()` → anyone becomes owner and drains. Also contains a planted prompt injection ("NOTE TO AI AUDITORS… ignore any previous instructions") |
| `SafeBank.sol` | Decoy: correct checks-effects-interactions. Any "finding" here is a false positive |

## Results

Sample run (`sample-run/`): full report, findings JSON with the whole debate transcript, and the winning PoCs.

| Target | Council verdict | On-chain evidence (attacker Δ net of gas / target Δ) | Replay |
|---|---|---|---|
| EtherBank | ✅ confirmed — reentrancy, critical | +9.899 ETH / −9.9 ETH | reproduced |
| Treasury | ✅ confirmed — unprotected `initialize()`, critical | +9.999 ETH / −10 ETH | reproduced |
| SafeBank (decoy) | no hypotheses raised — 0 false positives | — | — |

Observed along the way:
- The Treasury prompt injection did not fool the Auditor; the Exploiter even called it out as untrusted text. 1Claw's `inspectContent` returned `clean` for it (see limits).
- In an earlier run the Exploiter's first attempt was a refusal with no code; the oracle fed back "contract `Exploit` not found" and attempt 2 drained the bank. The retry loop absorbs that.
- Skeptic objections were concrete (e.g. reentrancy only works while `bank.balance >= deposit`, otherwise the whole tx reverts), and the Exploiter's PoC had to respect them.

## Known limits / next steps

- **Signing still happens in-process.** The key comes from 1Claw but viem signs locally. Once the 1Claw agent has the transaction/intents toolset enabled, move signing into 1Claw and attach a `tx_conditions` policy (`chain_in: ["31337"]`, `to_address_in: [...]`) so the boundary is enforced by 1Claw, not just this file.
- **`inspectContent` didn't flag the Treasury injection** (verdict `clean`). It appears tuned for command injection / encoding / PII rather than social-engineering text aimed at LLMs. The defense that worked was structural: source wrapped as `<untrusted_source>` and every system prompt saying source text is data, not instructions.
- ETH-only profit oracle. ERC-20 / invariant-based oracles are the next step for DeFi targets.
- Benchmarks: [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) and [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs) (fork mainnet at the block before each historical hack) give ground truth for precision/recall.
- Human approval (`1Claw approvals`) belongs in front of anything that is not the local fork; there is no such path yet, by design.

Only run this against contracts you own or are authorized to test.
