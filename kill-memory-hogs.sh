#!/bin/zsh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}=== Memory Usage Analysis ===${NC}\n"

# Get system memory info
echo "${YELLOW}Current Memory Status:${NC}"
top -l 1 | grep PhysMem
echo ""

# Get top memory consuming processes
echo "${YELLOW}Top 15 Memory-Consuming Processes:${NC}"
echo "PID\tMEMORY\tCOMMAND"
echo "---\t------\t-------"

# Create a temporary file to store process info
TMPFILE=$(mktemp)
ps aux | awk 'NR>1 {print $2, $4, $11}' | sort -k2 -rn | head -15 > "$TMPFILE"

# Display processes with index numbers
INDEX=1
declare -a PIDS
declare -a MEMS
declare -a CMDS

while read -r pid mem cmd; do
    printf "${GREEN}%2d)${NC} %-8s %-8s %s\n" "$INDEX" "$pid" "${mem}%" "$cmd"
    PIDS[$INDEX]=$pid
    MEMS[$INDEX]=$mem
    CMDS[$INDEX]=$cmd
    ((INDEX++))
done < "$TMPFILE"

echo ""
echo "${YELLOW}Options:${NC}"
echo "  - Enter process numbers to kill (e.g., 1 3 5)"
echo "  - Enter 'all' to kill all listed processes"
echo "  - Enter 'q' to quit without killing anything"
echo ""

# Get user input
read "choice?${BLUE}Enter your choice: ${NC}"

# Handle quit
if [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]]; then
    echo "${GREEN}Exiting without killing any processes.${NC}"
    rm "$TMPFILE"
    exit 0
fi

# Collect PIDs to kill
TO_KILL=()

if [[ "$choice" == "all" ]]; then
    # Kill all processes
    for i in {1..15}; do
        if [[ -n "${PIDS[$i]}" ]]; then
            TO_KILL+=("${PIDS[$i]}")
        fi
    done
else
    # Parse selected numbers
    for num in ${=choice}; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -lt $INDEX ]]; then
            TO_KILL+=("${PIDS[$num]}")
        fi
    done
fi

# Confirm before killing
if [[ ${#TO_KILL[@]} -eq 0 ]]; then
    echo "${RED}No valid processes selected.${NC}"
    rm "$TMPFILE"
    exit 1
fi

echo ""
echo "${YELLOW}Processes selected for termination:${NC}"
for pid in "${TO_KILL[@]}"; do
    ps -p "$pid" -o pid,rss,comm 2>/dev/null | tail -n +2
done

echo ""
read "confirm?${RED}Are you sure you want to kill these processes? (yes/no): ${NC}"

if [[ "$confirm" == "yes" ]] || [[ "$confirm" == "y" ]]; then
    echo ""
    echo "${YELLOW}Attempting to terminate processes...${NC}"
    
    for pid in "${TO_KILL[@]}"; do
        PROCESS_NAME=$(ps -p "$pid" -o comm= 2>/dev/null)
        if kill -15 "$pid" 2>/dev/null; then
            echo "${GREEN}✓${NC} Sent SIGTERM to PID $pid ($PROCESS_NAME)"
            sleep 0.5
            
            # Check if process is still running, force kill if needed
            if ps -p "$pid" > /dev/null 2>&1; then
                echo "${YELLOW}  Process still running, sending SIGKILL...${NC}"
                kill -9 "$pid" 2>/dev/null
                sleep 0.5
                
                if ps -p "$pid" > /dev/null 2>&1; then
                    echo "${RED}  ✗ Failed to kill PID $pid${NC}"
                else
                    echo "${GREEN}  ✓ Force killed PID $pid${NC}"
                fi
            fi
        else
            echo "${RED}✗${NC} Failed to send signal to PID $pid (may require sudo)"
        fi
    done
    
    echo ""
    echo "${GREEN}Operation complete!${NC}"
    echo ""
    echo "${YELLOW}Updated Memory Status:${NC}"
    top -l 1 | grep PhysMem
else
    echo "${GREEN}Operation cancelled.${NC}"
fi

# Cleanup
rm "$TMPFILE"
