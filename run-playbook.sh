#!/bin/bash
# =============================================================================
# Run Ansible Playbook with Environment Variables
# =============================================================================
# This script loads environment variables from .env file and runs Ansible
# Usage: ./run-playbook.sh [playbook] [additional args]
# Examples:
#   ./run-playbook.sh                          # Runs site.yml
#   ./run-playbook.sh site.yml                 # Runs site.yml
#   ./run-playbook.sh site.yml --tags base     # Runs with tags
# =============================================================================

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PLAYBOOK="${1:-site.yml}"
shift 2>/dev/null || true
ADDITIONAL_ARGS="$@"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and fill in your values:${NC}"
    echo -e "${CYAN}  cp .env.example .env${NC}"
    exit 1
fi

echo -e "${GREEN}Loading environment variables from .env...${NC}"

# Load environment variables from .env file
loaded_count=0
while IFS='=' read -r name value; do
    # Skip empty lines and comments
    if [[ -z "$name" || "$name" == \#* ]]; then
        continue
    fi
    
    # Trim whitespace
    name=$(echo "$name" | xargs)
    value=$(echo "$value" | xargs)
    
    # Remove quotes if present
    value="${value%\"}"
    value="${value#\"}"
    
    # Export environment variable
    export "$name=$value"
    echo -e "  ${CYAN}✓ $name${NC}"
    ((loaded_count++))
done < .env

echo -e "${GREEN}Loaded $loaded_count environment variables${NC}"
echo ""

# Verify critical variables are set
critical_vars=("ANSIBLE_HOST" "ANSIBLE_USER" "ANSIBLE_SSH_PRIVATE_KEY_FILE")
missing_vars=()

for var in "${critical_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
        echo -e "  ${RED}✗ $var is not set${NC}"
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}ERROR: Missing required environment variables!${NC}"
    echo -e "${YELLOW}Please set the following in your .env file:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "  ${CYAN}- $var${NC}"
    done
    exit 1
fi

echo -e "${GREEN}✓ All required variables are set${NC}"
echo ""

# Display command that will be run
echo -e "${YELLOW}Running: ansible-playbook -i inventory/hosts.yml $PLAYBOOK $ADDITIONAL_ARGS${NC}"
echo ""

# Run Ansible playbook
if ansible-playbook -i inventory/hosts.yml "$PLAYBOOK" $ADDITIONAL_ARGS; then
    echo ""
    echo -e "${GREEN}✓ Playbook completed successfully!${NC}"
else
    exitcode=$?
    echo ""
    echo -e "${RED}✗ Playbook failed with exit code $exitcode${NC}"
    exit $exitcode
fi
