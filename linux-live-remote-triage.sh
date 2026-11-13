#!/bin/bash

TARGET=$1
SOCKET="/tmp/ssh_pure_mux"

if [ -z "$TARGET" ]; then
    echo "Uso: $0 utente@ip_remoto"
    exit 1
fi

# Pulizia alla chiusura (Ctrl+C)
cleanup() {
    tput cnorm
    tput sgr0
    clear
    ssh -S "$SOCKET" -O exit "$TARGET" 2>/dev/null
    exit 0
}
trap cleanup INT TERM

# Avvia connessione SSH persistente
ssh -S "$SOCKET" -O exit "$TARGET" 2>/dev/null
ssh -M -S "$SOCKET" -fnNT -o ControlPersist=600 "$TARGET" || exit 1

clear
tput civis

while true; do
    ROWS=$(tput lines)
    COLS=$(tput cols)
    HALF_R=$((ROWS / 2))
    HALF_C=$((COLS / 2))
    MAX_W=$((HALF_C - 2))
    MAX_H=$((HALF_R - 3))

    # Invia i comandi via heredoc per evitare conflitti di virgolette
    RAW_DATA=$(ssh -S "$SOCKET" "$TARGET" "MAX_H=$MAX_H MAX_W=$MAX_W bash -s" << 'EOF' 2>/dev/null
echo '===SEC1==='
ps -eo pid,user,args --sort=-start_time | head -n "$MAX_H"

echo '===SEC2==='
(sudo -n ss -tunapH state established state syn-sent 2>/dev/null || ss -tunapH state established state syn-sent) | grep -vE '127\.0\.0\.1|\[::1\]' | while read -r line; do
    proto=$(echo "$line" | awk '{print $1}')
    remote=$(echo "$line" | awk '{print $(NF-1)}')
    proc_raw=$(echo "$line" | awk '{print $NF}')

    if [[ "$proc_raw" == *"pid="* ]]; then
        pid=$(echo "$proc_raw" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
        exe_path=$(sudo -n readlink -f "/proc/$pid/exe" 2>/dev/null || readlink -f "/proc/$pid/exe" 2>/dev/null)
        [ -z "$exe_path" ] && exe_path="(binario non leggibile)"
        printf "%-4s %-21s [%s] %s\n" "$proto" "$remote" "$pid" "$exe_path"
    else
        printf "%-4s %-21s %s\n" "$proto" "$remote" "(permessi negati)"
    fi
done | head -n "$MAX_H"

echo '===SEC3==='
ls -la /proc/*/exe 2>/dev/null | grep deleted | head -n 4
find /tmp /dev/shm /var/tmp -type f -printf '%TH:%TM:%TS %p\n' 2>/dev/null | sort -r | head -n $((MAX_H - 4))

echo '===SEC4==='
(sudo -n journalctl -n "$MAX_H" -u ssh -u sshd -u sudo --no-pager 2>/dev/null || journalctl -n "$MAX_H" -u ssh -u sshd -u sudo --no-pager 2>/dev/null || tail -n "$MAX_H" /var/log/auth.log /var/log/secure 2>/dev/null) | cut -c 1-"$MAX_W"
EOF
)

    # Estrae le 4 sezioni
    SEC1=$(echo "$RAW_DATA" | sed -n '/===SEC1===/,/===SEC2===/p' | grep -v '===SEC')
    SEC2=$(echo "$RAW_DATA" | sed -n '/===SEC2===/,/===SEC3===/p' | grep -v '===SEC')
    SEC3=$(echo "$RAW_DATA" | sed -n '/===SEC3===/,/===SEC4===/p' | grep -v '===SEC')
    SEC4=$(echo "$RAW_DATA" | sed -n '/===SEC4===/,$p' | grep -v '===SEC')

    draw_pane() {
        local start_r=$1
        local start_c=$2
        local title=$3
        local content=$4

        tput cup "$start_r" "$start_c"
        printf "\e[1;44;37m %-*.*s \e[0m" "$MAX_W" "$MAX_W" "$title"

        local r=$((start_r + 1))
        local count=0
        while IFS= read -r line; do
            [ $count -ge $MAX_H ] && break
            tput cup "$r" "$start_c"
            printf "%-*.*s" "$MAX_W" "$MAX_W" "$line"
            r=$((r + 1))
            count=$((count + 1))
        done <<< "$content"

        while [ $count -lt $MAX_H ]; do
            tput cup "$r" "$start_c"
            printf "%-*s" "$MAX_W" " "
            r=$((r + 1))
            count=$((count + 1))
        done
    }

    draw_pane 0 0 " ULTIMI PROCESSI AVVIATI" "$SEC1"
    draw_pane 0 "$HALF_C" " CONNESSIONI RETE ATTIVE (IP REMOTO)" "$SEC2"
    draw_pane "$HALF_R" 0 " BINARI DELETED & FILE /TMP" "$SEC3"
    draw_pane "$HALF_R" "$HALF_C" " LOG AUTENTICAZIONE / SUDO" "$SEC4"

    for ((i=0; i<ROWS; i++)); do
        tput cup "$i" $((HALF_C - 1))
        printf "│"
    done

    sleep 1
done

# watch -n 1 "ssh -S /tmp/ssh_mux root@target 'ps -eo pid,ppid,user,stat,lstart,args --sort=-start_time | head -n 25'"
# watch -n 1 "ssh -S /tmp/ssh_mux root@target 'ss -tunap | grep -v 127.0.0.1'"
# watch -n 1 "ssh -S /tmp/ssh_mux root@target 'ls -la /proc/*/exe 2>/dev/null | grep deleted'"
# watch -n 1 "ssh -S /tmp/ssh_mux root@target 'find /tmp /dev/shm /var/tmp -type f -printf \"%T+ %p\n\" 2>/dev/null | sort -r | head -n 15'"
