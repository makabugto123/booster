#!/data/data/com.termux/files/usr/bin/bash
# booster_multi.sh — test MANY domains across MANY DNS servers

VER="2.2.2"
# List all the domains you want to probe:
DOMAINS=( "google.com" "youtube.com" "facebook.com" )

DNS_LIST="$HOME/.dns_list.txt"   # one DNS IP per line
DIG_BIN="dig"                    # or your fastdig path
FAIL_LIMIT=5
DELAY=5                           # seconds between loops
VPN_IF="tun0"
RESTART_CMD="bash ~/dnstt/start-client.sh"

trap 'echo; echo "👋 Exiting booster."; exit 0' SIGINT

# bootstrap DNS list if missing
[[ ! -f $DNS_LIST ]] && cat > $DNS_LIST <<EOF
1.1.1.1
8.8.8.8
9.9.9.9
114.114.114.114
EOF

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
  local loop=0 total_fail
  while true; do
    ((loop++))
    echo -e "\n[+] GTM | BOOSTER v$VER | Loop #$loop"
    echo -e "    🟢 FAST ≤100ms   🟡 MED ≤250ms   🔴 SLOW >250ms"

    # check VPN
    if ! ip link show "$VPN_IF" &>/dev/null; then
      echo -e "⚠️  $VPN_IF DOWN — restarting..."
      restart_vpn
    fi

    total_fail=0
    # outer loop: domains
    for domain in "${DOMAINS[@]}"; do
      echo -e "\n=== Testing DOMAIN: \e[1;36m$domain\e[0m ==="
      # inner loop: DNS servers
      while read -r ip; do
        [[ -z $ip ]] && continue
        echo -e "\n⮞ $domain @ $ip"

        # ping test
        if out=$(ping -c1 -W2 "$ip" 2>/dev/null); then
          ms=$(awk -F'time=' '/time=/{print int($2)}' <<<"$out")
          printf "   Ping: "; color_ping "$ms"
        else
          echo -e "   Ping: \e[31mTIMEOUT\e[0m"
          ((total_fail++))
          continue
        fi

        # DNS lookup test
        if timeout 3 $DIG_BIN @"$ip" "$domain" &>/dev/null; then
          echo -e "   DNS : \e[32mOK\e[0m"
        else
          echo -e "   DNS : \e[31mFAIL\e[0m"
          ((total_fail++))
        fi
      done < "$DNS_LIST"
    done

    echo -e "\n📊 Total failures this loop: $total_fail"
    if (( total_fail >= FAIL_LIMIT )); then
      echo -e "⚠️  Too many fails — restarting tunnel"
      restart_vpn
    fi

    sleep "$DELAY"
  done
}

main
