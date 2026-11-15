// One-time 1Claw setup for the council (needs a human/user API key, because agents and policies are human-only):
//   ONECLAW_USER_API_KEY=1ck_... bun setup-1claw.ts
// Creates the `pentest-council` vault, lets the orchestrator agent (mcp-agent) use it, creates one child agent
// per council member that can read ONLY its own wallet, and generates each member's wallet. Idempotent.
import { createClient } from "@1claw/sdk";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

const BASE = process.env.ONECLAW_API_URL ?? "https://api.1claw.co";
const VAULT = process.env.ONECLAW_VAULT_NAME ?? "pentest-council";
const ORCHESTRATOR = process.env.ONECLAW_ORCHESTRATOR ?? "mcp-agent";
const MEMBERS = ["auditor-sonnet", "skeptic-opus", "exploiter-sonnet"]; // must match account() in council.ts
if (!process.env.ONECLAW_USER_API_KEY) throw new Error("set ONECLAW_USER_API_KEY (a 1ck_ user key from the 1Claw dashboard)");
const oc = createClient({ baseUrl: BASE, apiKey: process.env.ONECLAW_USER_API_KEY });

function must<T>(r: { data: T | null; error: { message: string } | null }, what: string): T {
  if (r.error || r.data == null) throw new Error(`${what}: ${r.error?.message ?? "no data"}`);
  return r.data;
}
const log = (s: string) => console.log(`\x1b[35m1Claw\x1b[0m ${s}`);

// 1. vault
const vaults = must(await oc.vault.list(), "vault.list").vaults ?? [];
const vault = vaults.find(v => v.name === VAULT) ?? must(await oc.vault.create({ name: VAULT, description: "AI pentest council: attacker key, bounty payer key, agent wallets" }), "vault.create");
log(`vault ${VAULT} = ${vault.id}`);

// 2. orchestrator gets read/write on the whole vault
const agents = must(await oc.agents.list(), "agents.list").agents ?? [];
const orch = agents.find(a => a.name === ORCHESTRATOR);
if (!orch) throw new Error(`agent ${ORCHESTRATOR} not found`);
const grants = must(await oc.access.listGrants(vault.id), "access.listGrants").policies ?? [];
const hasGrant = (id: string, pattern: string) => grants.some((g: any) => g.principal_id === id && g.secret_path_pattern === pattern);
if (!hasGrant(orch.id, "**")) must(await oc.access.grantAgent(vault.id, orch.id, ["read", "write"], { secretPathPattern: "**" }), "grant orchestrator");
log(`${ORCHESTRATOR} (${orch.id}) → read/write ${VAULT}/**`);

// 3. wallets (orchestrator-side generation, key never printed) + 4. one child agent per member
const children = must(await oc.agents.listChildren(orch.id), "agents.listChildren").agents ?? [];
for (const m of MEMBERS) {
  const keyPath = `wallets/${m}/key`;
  const existing = await oc.secrets.get(vault.id, keyPath);
  const pk = (existing.data?.value ?? generatePrivateKey()) as `0x${string}`;
  const address = privateKeyToAccount(pk).address;
  if (!existing.data) {
    must(await oc.secrets.set(vault.id, keyPath, pk, { type: "private_key", metadata: { member: m, address } }), `set ${keyPath}`);
    must(await oc.secrets.set(vault.id, `wallets/${m}/address`, address, { type: "note", metadata: { member: m } }), `set wallets/${m}/address`);
  }

  const name = `council-${m.split("-")[0]}`;
  let child = children.find(c => c.name === name) ?? agents.find(a => a.name === name);
  if (!child) {
    const created = await oc.agents.createChild(orch.id, { name, description: `Pentest council member ${m}. Can read only its own wallet.`, vault_ids: [vault.id] });
    const res = created.data ?? must(await oc.agents.create({ name, description: `Pentest council member ${m}. Can read only its own wallet.` }), `create ${name}`);
    child = res.agent;
    if (res.api_key) must(await oc.secrets.set(vault.id, `agents/${name}/api-key`, res.api_key, { type: "api_key", metadata: { agent_id: child.id } }), `store ${name} key`);
    log(`created ${created.data ? "child" : "agent"} ${name} (${child.id}); its API key is stored at ${VAULT}/agents/${name}/api-key`);
  }
  if (!hasGrant(child.id, `wallets/${m}/**`)) must(await oc.access.grantAgent(vault.id, child.id, ["read"], { secretPathPattern: `wallets/${m}/**` }), `grant ${name}`);
  log(`${name} → read ${VAULT}/wallets/${m}/**   wallet ${address}`);
}
log(`done. council.ts now uses vault ${VAULT} automatically.`);
