# Agent prompts — one-shot Surge deploys

Drop-in [Claude Code](https://docs.claude.com/en/docs/claude-code) subagent prompts that take a Surge deploy from a clean repo to a verified L2 in one shot. Each prompt is self-contained: open the file, fill in a few placeholders at the top, paste the fenced block into your LLM model as a `general-purpose` subagent prompt, and watch it run.

## Pick a prompt

| File | Topology | Prover | When to use |
|------|----------|--------|-------------|
| [`deploy-mock-prover.md`](./deploy-mock-prover.md) | Single VM (or laptop) | Mock | Local dev, CI, fast iteration. No GPU required. |
| [`deploy-real-zisk-same-vm.md`](./deploy-real-zisk-same-vm.md) | Single VM | Real ZisK | One-host staging on a beefy GPU box (realistic with 4× L40+). |
| [`deploy-real-zisk-two-vm.md`](./deploy-real-zisk-two-vm.md) | Two VMs (L2 host + prover) | Real ZisK | Production-like deploys; isolates the GPU workload. |

Privacy mode is an orthogonal opt-in inside each prompt — flip a single parameter and the agent runs the right keygen + sync steps.

## How to use one

1. **Read the prompt's header.** Each file lists the placeholders (`<prover-host>`, `<l2-host>`, `<ssh-key-path>`, …) you need to substitute. Don't paste the prompt with brackets still in it — the agent has no way to guess.
2. **Run the local pre-flight.** Each prompt opens with a 30-second host check (image manifest reachable, SSH works, GPU present). Failures here are infra problems; fix them before launching the agent.
3. **Launch as a subagent.** In your LLM model, ask the parent agent to spawn a `general-purpose` subagent with the fenced block as the prompt. Foreground mode is recommended so you can watch progress — real ZisK cold starts run ~16 min per restart on a single GPU.
4. **Let it report back.** Every prompt ends with a "REPORT BACK" section telling the subagent what to write per phase. Don't kill the run inside a documented cold-start window.

## Conventions across all prompts

- **`--force` is mandatory.** Both `deploy-prover.sh` and `deploy-surge-full.sh` block on interactive prompts; an SSH-launched subagent can't answer them.
- **No commits, no pushes.** The prompts forbid the agent from touching git history. Anything that needs to be persisted is your call.
- **Secrets stay on disk.** `.privacy.env` is `chmod 600` and gitignored. The agent never echoes secrets back into reports.
- **Defer to the canonical docs.** Each prompt links the operator-facing guide on [docs.surge.wtf](https://docs.surge.wtf/guides/running-surge) — those pages are the source of truth if the prompt and the docs disagree.
- **Cold-start budgets are quoted, not negotiable.** A single-GPU prover takes ~16 min for the first proof after each `--force-recreate`. The prompts pre-quote total wall time so the agent waits instead of retrying.

## Updating these prompts

When you change a deploy script's behavior — flag names, defaults, ordering, new pre-flight checks — update the matching prompt in lockstep and tick the "Provenance" footer at the bottom of the file with the date and what changed. Stale prompts are worse than no prompt: they confidently lead agents into removed flags or skipped steps.
