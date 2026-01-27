alias updateff='
LOCAL_VER=$(/opt/firefox-beta/firefox -v | awk "{print \$3}");
REMOTE_VER=$(wget --spider -S --max-redirect 0 "https://download.mozilla.org/?product=firefox-beta-latest-ssl&os=linux64&lang=en-US" 2>&1 | sed -n "/Location: /{s|.*/firefox-\(.*\)\.tar.*|\1|p;q;}");
if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
    echo "Firefox Beta is already up to date ($LOCAL_VER).";
else
    echo "Updating Firefox: $LOCAL_VER -> $REMOTE_VER...";
    curl -L "https://download.mozilla.org/?product=firefox-beta-latest-ssl&os=linux64&lang=en-US" | sudo tar -xjC /opt/ && \
    sudo chown -R root:root /opt/firefox-beta && \
    sudo chmod -R 755 /opt/firefox-beta && \
    echo "Update complete! Please restart Firefox to apply changes.";
fi'
