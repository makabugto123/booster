cat > install_boost.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/env bash
set -e

echo -e "\n🔄 Updating Termux repos & packages…"
termux-change-repo
pkg update -y && pkg upgrade -y

echo -e "\n📦 Installing dependencies…"
pkg install -y curl wget git nano grep busybox proot tar unzip dnsutils

echo -e "\n🌐 Forcing Google DNS…"
echo "nameserver 8.8.8.8" > "$PREFIX/etc/resolv.conf"

echo -e "\n📥 Downloading booster script…"
mkdir -p "$HOME/bin"
wget -q https://raw.githubusercontent.com/makabugto123/booster/main/boost.sh -O "$HOME/bin/boost"
chmod +x "$HOME/bin/boost"

echo -e "\n🔧 Ensuring ~/bin is in your PATH…"
if ! grep -qxF 'export PATH=$HOME/bin:$PATH' "$HOME/.bashrc"; then
  echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.bashrc"
fi

echo -e "\n✅ Installation complete!"
echo "→ Restart Termux or run: source ~/.bashrc"
echo "→ Then just type: boost"

EOF
chmod +x install_boost.sh
