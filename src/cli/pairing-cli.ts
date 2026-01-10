import type { Command } from "commander";

import { loadConfig } from "../config/config.js";
import { resolvePairingIdLabel } from "../pairing/pairing-labels.js";
import {
  approveProviderPairingCode,
  listProviderPairingRequests,
  type PairingProvider,
} from "../pairing/pairing-store.js";
import {
  listPairingProviders,
  notifyPairingApproved,
  resolvePairingProvider,
} from "../providers/plugins/pairing.js";

const PROVIDERS: PairingProvider[] = listPairingProviders();

function parseProvider(raw: unknown): PairingProvider {
  return resolvePairingProvider(raw);
}

async function notifyApproved(provider: PairingProvider, id: string) {
  const cfg = loadConfig();
  await notifyPairingApproved({ providerId: provider, id, cfg });
}

export function registerPairingCli(program: Command) {
  const pairing = program
    .command("pairing")
    .description("Secure DM pairing (approve inbound requests)");

  pairing
    .command("list")
    .description("List pending pairing requests")
    .requiredOption(
      "--provider <provider>",
      `Provider (${PROVIDERS.join(", ")})`,
    )
    .option("--json", "Print JSON", false)
    .action(async (opts) => {
      const provider = parseProvider(opts.provider);
      const requests = await listProviderPairingRequests(provider);
      if (opts.json) {
        console.log(JSON.stringify({ provider, requests }, null, 2));
        return;
      }
      if (requests.length === 0) {
        console.log(`No pending ${provider} pairing requests.`);
        return;
      }
      for (const r of requests) {
        const meta = r.meta ? JSON.stringify(r.meta) : "";
        const idLabel = resolvePairingIdLabel(provider);
        console.log(
          `${r.code}  ${idLabel}=${r.id}${meta ? `  meta=${meta}` : ""}  ${r.createdAt}`,
        );
      }
    });

  pairing
    .command("approve")
    .description("Approve a pairing code and allow that sender")
    .requiredOption(
      "--provider <provider>",
      `Provider (${PROVIDERS.join(", ")})`,
    )
    .argument("<code>", "Pairing code (shown to the requester)")
    .option("--notify", "Notify the requester on the same provider", false)
    .action(async (code, opts) => {
      const provider = parseProvider(opts.provider);
      const approved = await approveProviderPairingCode({
        provider,
        code: String(code),
      });
      if (!approved) {
        throw new Error(`No pending pairing request found for code: ${code}`);
      }

      console.log(`Approved ${provider} sender ${approved.id}.`);

      if (!opts.notify) return;
      await notifyApproved(provider, approved.id).catch((err) => {
        console.log(`Failed to notify requester: ${String(err)}`);
      });
    });
}
