#!/data/data/com.termux/files/usr/bin/bash
#
# booster1.sh — test ONE domain across MANY DNS servers
# usage:   ./booster1.sh
# stops on Ctrl+C

VER="2.2.2"
DOMAIN="vpn.kagerou.site"        # ← set your single domain here
DNS_LIST="$HOME/.dns_list.txt"   # one DNS IP per line
DIG_BIN="~/go/bin/fastdig"       # or just "dig"
FAIL_LIMIT=5
DELAY=5                           # seconds between loops
VPN_IF="tun0"
RESTART_CMD="bash ~/dnstt/start-client.sh"

trap 'echo; echo "👋 Exiting booster."; exit 0' SIGINT

# bootstrap DNS list if missing
[[ ! -f $DNS_LIST ]] && cat > $DNS_LIST <<EOF
124.6.181.25
124.6.181.26
124.6.181.27
124.6.181.31
124.6.181.160
124.6.181.171
EOF

# color-coded ping
color_ping(){
  local ms=$1
  if   (( ms<=100 )); then printf "\e[32m%4sms FAST\e[0m\n" "$ms"
  elif (( ms<=250 )); then printf "\e[33m%4sms MEDM \e[0m\n" "$ms"
  else                   printf "\e[31m%4sms SLOW\e[0m\n" "$ms"; fi
}

restart_vpn(){
  echo -e "\n\e[33m[!] Restarting DNSTT client...\e[0m"
  pkill -f dnstt-client &>/dev/null
  eval "$RESTART_CMD" & sleep 2
}

main(){
  local loop=0 failsum
  while true; do
    ((loop++))
    failsum=0
    echo -e "\n[+] GTM | BOOSTER v$VER | Loop #$loop"
    echo -e "    Testing: \e[1;36m$DOMAIN\e[0m"
    echo -e "    🟢 FAST ≤100ms   🟡 MED ≤250ms   🔴 SLOW >250ms"

    # check VPN
    if ! ip link show "$VPN_IF" &>/dev/null; then
      echo -e "⚠️  $VPN_IF DOWN — restarting..."
      restart_vpn
    fi

    # loop over DNS servers
    while read -r ip; do
      [[ -z $ip ]] && continue
      echo -e "\n⮞ $DOMAIN @ $ip"

      # ping
      if out=$(ping -c1 -W2 "$ip" 2>/dev/null); then
        ms=$(awk -F'time=' '/time=/{print int($2)}' <<<"$out")
        printf "   Ping: "; color_ping "$ms"
      else
        echo -e "   Ping: \e[31mTIMEOUT\e[0m"
        ((failsum++))
        continue
      fi

      # DNS lookup
      if timeout 3 $DIG_BIN @"$ip" "$DOMAIN" &>/dev/null; then
        echo -e "   DNS : \e[32mOK\e[0m"
      else
        echo -e "   DNS : \e[31mFAIL\e[0m"
        ((failsum++))
      fi
    done < "$DNS_LIST"

    echo -e "\n📊 Failures this loop: $failsum"
    if (( failsum >= FAIL_LIMIT )); then
      echo -e "⚠️  Too many fails — restarting tunnel"
      restart_vpn
    fi

    sleep "$DELAY"
  done
}

main
