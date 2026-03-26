#!/bin/bash

# Quinn's Epic AI Workflow - Setup Script
# Sets up the dual-agent pipeline (Codex + Claude Code + Ollama)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║       Quinn's Epic AI Workflow - Setup Script             ║"
echo "║   Dual-Agent Pipeline: Codex (Night) + Claude (Morning)   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect environment
detect_environment() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

ENV=$(detect_environment)
echo -e "${BLUE}Detected environment: ${ENV}${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${BOLD}Checking prerequisites...${NC}"

    local missing=()

    if ! command -v node &> /dev/null; then
        missing+=("Node.js 18+")
    else
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -lt 18 ]; then
            missing+=("Node.js 18+ (current: $(node -v))")
        else
            echo -e "${GREEN}✓${NC} Node.js $(node -v)"
        fi
    fi

    if ! command -v npm &> /dev/null; then
        missing+=("npm")
    else
        echo -e "${GREEN}✓${NC} npm $(npm -v)"
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    else
        echo -e "${GREEN}✓${NC} git $(git --version | cut -d' ' -f3)"
    fi

    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} Python 3.10+ (optional, for some tools)"
    else
        echo -e "${GREEN}✓${NC} Python $(python3 --version | cut -d' ' -f2)"
    fi

    # Check for NVIDIA GPU (WSL/Linux)
    if [[ "$ENV" == "wsl" || "$ENV" == "linux" ]]; then
        if command -v nvidia-smi &> /dev/null; then
            GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
            GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
            echo -e "${GREEN}✓${NC} GPU: $GPU_NAME ($GPU_MEM)"
        else
            echo -e "${YELLOW}⚠${NC} No NVIDIA GPU detected (local models will be slower)"
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Missing prerequisites:${NC}"
        for item in "${missing[@]}"; do
            echo -e "  ${RED}✗${NC} $item"
        done
        echo ""
        echo "Please install missing prerequisites and run this script again."
        exit 1
    fi

    echo ""
}

# Install Ollama and models
install_ollama() {
    echo -e "${BOLD}Step 1: Ollama + Local Models${NC}"

    if command -v ollama &> /dev/null; then
        echo -e "${GREEN}✓${NC} Ollama already installed"
    else
        echo -e "${BLUE}Installing Ollama...${NC}"
        curl -fsSL https://ollama.com/install.sh | sh
        echo -e "${GREEN}✓${NC} Ollama installed"
    fi

    # Start Ollama service if not running
    if ! pgrep -x "ollama" > /dev/null; then
        echo -e "${BLUE}Starting Ollama service...${NC}"
        ollama serve &> /dev/null &
        sleep 3
    fi

    # Pull models
    echo -e "${BLUE}Pulling Qwen models (this may take a while)...${NC}"

    echo "  Pulling qwen2.5-coder:32b..."
    if ollama pull qwen2.5-coder:32b 2>&1 | tail -1; then
        echo -e "  ${GREEN}✓${NC} qwen2.5-coder:32b"
    else
        echo -e "  ${YELLOW}⚠${NC} qwen2.5-coder:32b (may need more VRAM, try 7b variant)"
    fi

    echo "  Pulling qwen3.5:27b..."
    if ollama pull qwen3.5:27b 2>&1 | tail -1; then
        echo -e "  ${GREEN}✓${NC} qwen3.5:27b"
    else
        echo -e "  ${YELLOW}⚠${NC} qwen3.5:27b (may need more VRAM)"
    fi

    echo ""
}

# Install Codex CLI
install_codex() {
    echo -e "${BOLD}Step 2: OpenAI Codex CLI${NC}"

    if command -v codex &> /dev/null; then
        echo -e "${GREEN}✓${NC} Codex CLI already installed"
    else
        echo -e "${BLUE}Installing Codex CLI...${NC}"
        npm install -g @openai/codex
        echo -e "${GREEN}✓${NC} Codex CLI installed"
    fi

    # Check auth
    if codex auth status &> /dev/null; then
        echo -e "${GREEN}✓${NC} Codex authenticated"
    else
        echo -e "${YELLOW}!${NC} Codex needs authentication"
        echo "  Run: codex auth"
        echo "  (Requires ChatGPT Plus subscription)"
    fi

    echo ""
}

# Install Claude Code
install_claude() {
    echo -e "${BOLD}Step 3: Claude Code CLI${NC}"

    if command -v claude &> /dev/null; then
        echo -e "${GREEN}✓${NC} Claude Code already installed"
    else
        echo -e "${BLUE}Installing Claude Code...${NC}"
        npm install -g @anthropic-ai/claude-code
        echo -e "${GREEN}✓${NC} Claude Code installed"
    fi

    # Check if authenticated (basic check)
    if [ -f "$HOME/.claude/credentials.json" ] || [ -f "$HOME/.config/claude/credentials.json" ]; then
        echo -e "${GREEN}✓${NC} Claude Code credentials found"
    else
        echo -e "${YELLOW}!${NC} Claude Code needs authentication"
        echo "  Run: claude"
        echo "  (Requires Claude Pro subscription)"
    fi

    echo ""
}

# Configure MCP servers
configure_mcp() {
    echo -e "${BOLD}Step 4: MCP Servers${NC}"

    echo -e "${BLUE}Adding MCP servers to Claude Code...${NC}"

    # These commands are idempotent - safe to run multiple times
    claude mcp add context7 -- npx -y @upstash/context7-mcp@latest 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} context7 (library docs)"

    claude mcp add memory -- npx -y @modelcontextprotocol/server-memory 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} memory (cross-session)"

    claude mcp add eslint -- npx -y @eslint/mcp 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} eslint"

    # GitHub MCP needs token
    if [ -n "$GITHUB_TOKEN" ]; then
        claude mcp add github -- npx -y @modelcontextprotocol/server-github 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} github"
    else
        echo -e "  ${YELLOW}⚠${NC} github (set GITHUB_TOKEN to enable)"
    fi

    claude mcp add playwright -- npx -y @anthropic-ai/mcp-playwright 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} playwright (UI testing)"

    claude mcp add desktop-commander -- npx -y @anthropic-ai/mcp-desktop-commander 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} desktop-commander"

    echo ""
}

# Install RALPH plugin
install_ralph() {
    echo -e "${BOLD}Step 5: RALPH Plugin (for interactive Claude sessions)${NC}"

    # Check if RALPH config exists in Claude settings
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$CLAUDE_SETTINGS" ] && grep -q "ralph" "$CLAUDE_SETTINGS" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} RALPH appears to be configured"
    else
        echo -e "${YELLOW}!${NC} RALPH plugin requires manual installation from Claude Code"
        echo ""
        echo "  After setup completes, run:"
        echo "    claude"
        echo "    /plugin marketplace add anthropics/ralph-wiggum"
        echo ""
        echo "  Or use the community version with more safety rails:"
        echo "    git clone https://github.com/frankbria/ralph-claude-code ~/.ralph"
        echo ""
        echo "  RALPH is used for interactive Claude sessions (daytime work)."
        echo "  Overnight automation uses Codex, not RALPH."
    fi

    echo ""
}

# Install LiteLLM proxy (bridges Claude Code → Ollama)
install_litellm() {
    echo -e "${BOLD}Step 6: LiteLLM Proxy (Claude Code → Ollama Gateway)${NC}"

    if command -v litellm &> /dev/null; then
        echo -e "${GREEN}✓${NC} LiteLLM already installed"
    else
        echo -e "${BLUE}Installing LiteLLM proxy...${NC}"
        if command -v pip3 &> /dev/null; then
            pip3 install 'litellm[proxy]' --quiet
            echo -e "${GREEN}✓${NC} LiteLLM installed"
        elif command -v pip &> /dev/null; then
            pip install 'litellm[proxy]' --quiet
            echo -e "${GREEN}✓${NC} LiteLLM installed"
        else
            echo -e "${YELLOW}⚠${NC} pip not found - install LiteLLM manually: pip install litellm[proxy]"
        fi
    fi

    if [ -f "litellm-config.yaml" ]; then
        echo -e "${GREEN}✓${NC} litellm-config.yaml found"
    else
        echo -e "${YELLOW}⚠${NC} litellm-config.yaml missing - copy from template repo"
    fi

    echo ""
    echo "  To start the gateway:  ./scripts/start-litellm.sh"
    echo "  To run in background:  ./scripts/start-litellm.sh --bg"
    echo ""
}

# Make scripts executable
setup_scripts() {
    echo -e "${BOLD}Step 7: Script Permissions${NC}"

    chmod +x scripts/*.sh 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Made scripts executable"

    echo ""
}

# Create .env template
create_env_template() {
    echo -e "${BOLD}Step 8: Environment Template${NC}"

    if [ ! -f ".env" ]; then
        cat > .env.example << 'EOF'
# Quinn's Epic AI Workflow - Environment Variables

# GitHub (for MCP server)
GITHUB_TOKEN=your_github_personal_access_token

# Ollama (usually localhost)
OLLAMA_HOST=http://localhost:11434

# LiteLLM proxy (bridges Claude Code → Ollama)
# Start with: ./scripts/start-litellm.sh
# ANTHROPIC_BASE_URL=http://localhost:4000

# Subagent model routing (via LiteLLM gateway)
# CLAUDE_CODE_SUBAGENT_MODEL=qwen3.5:27b
EOF
        echo -e "${GREEN}✓${NC} Created .env.example"
        echo "  Copy to .env and fill in your tokens"
    else
        echo -e "${GREEN}✓${NC} .env already exists"
    fi

    echo ""
}

# Verify installation
verify_installation() {
    echo -e "${BOLD}Verification${NC}"
    echo "─────────────"

    local all_good=true

    if command -v ollama &> /dev/null; then
        echo -e "${GREEN}✓${NC} Ollama"
    else
        echo -e "${RED}✗${NC} Ollama"
        all_good=false
    fi

    if command -v codex &> /dev/null; then
        echo -e "${GREEN}✓${NC} Codex CLI"
    else
        echo -e "${RED}✗${NC} Codex CLI"
        all_good=false
    fi

    if command -v claude &> /dev/null; then
        echo -e "${GREEN}✓${NC} Claude Code"
    else
        echo -e "${RED}✗${NC} Claude Code"
        all_good=false
    fi

    if [ -f "AGENTS.md" ] && [ -f "STATUS.md" ] && [ -f "CLAUDE.md" ]; then
        echo -e "${GREEN}✓${NC} Workflow files"
    else
        echo -e "${RED}✗${NC} Workflow files"
        all_good=false
    fi

    if [ -x "scripts/overnight-codex.sh" ]; then
        echo -e "${GREEN}✓${NC} Overnight script"
    else
        echo -e "${RED}✗${NC} Overnight script"
        all_good=false
    fi

    if command -v litellm &> /dev/null; then
        echo -e "${GREEN}✓${NC} LiteLLM proxy"
    else
        echo -e "${YELLOW}⚠${NC} LiteLLM proxy (optional, for local model routing)"
    fi

    echo ""

    if $all_good; then
        echo -e "${GREEN}${BOLD}Setup complete!${NC}"
    else
        echo -e "${YELLOW}${BOLD}Setup partially complete - see above for issues${NC}"
    fi
}

# Print next steps
print_next_steps() {
    echo ""
    echo -e "${BOLD}Next Steps${NC}"
    echo "──────────"
    echo ""
    echo "1. Authenticate (if not already done):"
    echo "   codex auth      # ChatGPT Plus account"
    echo "   claude          # Claude Pro account"
    echo ""
    echo "2. Install RALPH plugin (for interactive Claude sessions):"
    echo "   claude"
    echo "   /plugin marketplace add anthropics/ralph-wiggum"
    echo "   # Or run /setup-ralph for guidance"
    echo ""
    echo "3. Verify student credits (optional):"
    echo "   codex credits"
    echo ""
    echo "4. Edit your first task list:"
    echo "   vim AGENTS.md"
    echo ""
    echo "5. Start the LiteLLM gateway (for local model routing):"
    echo "   ./scripts/start-litellm.sh --bg"
    echo ""
    echo "6. Run your first overnight session:"
    echo "   ./scripts/overnight-codex.sh"
    echo ""
    echo "7. Morning review:"
    echo "   claude"
    echo "   /review"
    echo ""
    echo -e "${BLUE}Documentation: README.md${NC}"
    echo -e "${BLUE}Spec template: .claude/specs/_template.md${NC}"
    echo ""
}

# Main
main() {
    check_prerequisites
    install_ollama
    install_codex
    install_claude
    configure_mcp
    install_ralph
    install_litellm
    setup_scripts
    create_env_template
    verify_installation
    print_next_steps
}

# Run with option to skip steps
case "${1:-}" in
    --skip-ollama)
        check_prerequisites
        install_codex
        install_claude
        configure_mcp
        install_ralph
        setup_scripts
        create_env_template
        verify_installation
        print_next_steps
        ;;
    --verify-only)
        verify_installation
        ;;
    --help)
        echo "Usage: ./scripts/setup.sh [option]"
        echo ""
        echo "Options:"
        echo "  (none)         Full setup"
        echo "  --skip-ollama  Skip Ollama installation"
        echo "  --verify-only  Just verify installation"
        echo "  --help         Show this help"
        ;;
    *)
        main
        ;;
esac
