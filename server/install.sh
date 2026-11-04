#!/bin/bash
# تركيب «مكتبي» على السيرفر (Ubuntu) ورا Caddy — بيانات لوحة النيابة مش بتتلمس
# الاستخدام: curl -fsSL https://mahmoud-board.github.io/Mahmoud-Office/server/install.sh | sudo bash -s my.pp-board22.com
set -e
DOMAIN="${1:-my.pp-board22.com}"
SRC="https://mahmoud-board.github.io/Mahmoud-Office/server"
APP=/opt/maktabi
echo "== تركيب مكتبي على: $DOMAIN"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 curl fonts-noto-core >/dev/null
id maktabi >/dev/null 2>&1 || useradd --system --home-dir "$APP" --shell /usr/sbin/nologin maktabi
mkdir -p "$APP/data"
echo "== تنزيل البرنامج"
curl -fsSL "$SRC/maktabi-server.zip" -o /tmp/maktabi-server.zip
python3 -m zipfile -e /tmp/maktabi-server.zip "$APP/"
rm -f /tmp/maktabi-server.zip
chown -R maktabi:maktabi "$APP"
chmod 700 "$APP/data"
if ! command -v google-chrome >/dev/null 2>&1; then
  echo "== تنزيل Chrome (عشان الـPDF)"
  if curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb; then
    apt-get install -y -qq /tmp/chrome.deb >/dev/null || echo "!! Chrome ما اتركبش — الـPDF هيطلع من نافذة الطباعة"
    rm -f /tmp/chrome.deb
  fi
fi
echo "== تشغيل الخدمة"
cat > /etc/systemd/system/maktabi.service <<UNIT
[Unit]
Description=Maktabi personal prosecutor board
After=network.target

[Service]
User=maktabi
Group=maktabi
WorkingDirectory=$APP
Environment=MAKTABI_NO_BROWSER=1
Environment=MAKTABI_HOSTS=$DOMAIN
Environment=MAKTABI_SECURE=1
Environment=MAKTABI_PORT=8770
Environment=HOME=$APP
ExecStart=/usr/bin/python3 $APP/server.py
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now maktabi
systemctl restart maktabi
echo "== ربط الدومين في Caddy"
CF=/etc/caddy/Caddyfile
if ! grep -q "^$DOMAIN" "$CF"; then
  cp "$CF" "$CF.bak-$(date +%Y%m%d%H%M%S)"
  printf '\n%s {\n\tencode gzip\n\treverse_proxy 127.0.0.1:8770\n}\n' "$DOMAIN" >> "$CF"
  if caddy validate --config "$CF" --adapter caddyfile >/dev/null 2>&1; then
    systemctl reload caddy
  else
    cp "$(ls -t $CF.bak-* | head -1)" "$CF"
    echo "!! ملف Caddy فيه مشكلة — رجعته زي ما كان ومحدش اتأثر"; exit 1
  fi
fi
cat > /usr/local/bin/maktabi-update <<'UPD'
#!/bin/bash
# تحديث مكتبي: بيبدل ملفات البرنامج بس — فولدر data مبيتلمسش
set -e
APP=/opt/maktabi
curl -fsSL https://mahmoud-board.github.io/Mahmoud-Office/server/maktabi-server.zip?t=$(date +%s) -o /tmp/maktabi-server.zip
python3 -m zipfile -e /tmp/maktabi-server.zip "$APP/"
rm -f /tmp/maktabi-server.zip
chown -R maktabi:maktabi "$APP"
systemctl restart maktabi
echo "== اتحدث مكتبي — افتح الرابط تاني"
UPD
chmod +x /usr/local/bin/maktabi-update
sleep 2
if systemctl is-active --quiet maktabi; then
  echo "=================================================="
  echo " تمام — مكتبي شغال على: https://$DOMAIN"
  echo " للتحديث بعد كده:  maktabi-update"
  echo "=================================================="
else
  echo "!! الخدمة مش شغالة:"; journalctl -u maktabi -n 20 --no-pager
fi
