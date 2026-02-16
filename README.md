# claude-sandbox

Docker-based isolation for running multiple Claude Code instances with `--dangerously-skip-permissions`. Each git worktree gets its own container with filesystem and network isolation.

## What's isolated

| Concern | Protection |
|---------|-----------|
| Filesystem | Container only sees the bind-mounted worktree + Claude config |
| Network | Firewall whitelist blocks exfiltration to arbitrary hosts |
| Credentials | ~/.ssh, ~/.aws, etc. are NOT mounted |
| Cross-worktree | Each container is separate |
| Resources | Memory and CPU limits prevent starvation |

## Setup

Build the image (once):

```bash
docker build -t claude-sandbox .
```

Authenticate on the host first (Max/Pro plan):

```bash
claude login
```

Or for API key users, export `ANTHROPIC_API_KEY` and add `-e ANTHROPIC_API_KEY` to the docker run command in `claude-worktree.sh`.

## Usage

### Single worktree

```bash
./claude-worktree.sh /path/to/worktree [session-name]
```

### Multiple worktrees in tmux

Point at an existing repo and specify how many worktrees to create:

```bash
./spin-up-team.sh <repo-path> <num-worktrees> [base-branch]
```

For example, spin up 3 isolated Claude instances all branching from `main`:

```bash
./spin-up-team.sh ~/dev/my-project 3 main
```

This creates worktrees under `~/dev/my-project-worktrees/` (`worker-1`, `worker-2`, `worker-3`), each on its own branch, and opens a tmux session with one pane per worker. If the worktrees already exist they are reused, so the command is safe to re-run.

If `base-branch` is omitted, worktrees branch from the repo's current HEAD.

### Cleanup

When you're done, remove the worktrees, branches, and tmux session:

```bash
./cleanup-team.sh <repo-path>
```

This stops any running containers, removes all `worker-*` worktrees and branches from the repo, and cleans up the worktrees directory.

## Firewall whitelist

Outbound traffic is blocked by default. Only these hosts are allowed:

- `api.anthropic.com` - Claude API
- `claude.ai` - OAuth authentication
- `statsig.anthropic.com` - Feature flags
- `sentry.io` - Error reporting
- `github.com` - Git operations (HTTPS + SSH)
- `registry.npmjs.org` - npm packages

Edit `firewall-init.sh` to add more hosts.

## Files

- `Dockerfile` - Base image (Node 20, Claude Code, iptables)
- `firewall-init.sh` - Default-deny firewall with whitelist
- `claude-worktree.sh` - Launch one isolated container
- `spin-up-team.sh` - Launch multiple containers in tmux
- `cleanup-team.sh` - Remove worktrees, branches, and tmux session
