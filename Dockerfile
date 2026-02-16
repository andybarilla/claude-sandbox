FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y \
    git curl jq iptables bubblewrap socat \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Firewall: default-deny outbound, whitelist only what's needed
COPY firewall-init.sh /usr/local/bin/firewall-init.sh
RUN chmod +x /usr/local/bin/firewall-init.sh

RUN useradd -m -s /bin/bash claude

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
