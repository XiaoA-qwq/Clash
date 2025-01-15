#!/bin/sh

SKIPUNZIP=1
ASH_STANDALONE=1

SURFING_PATH="/data/adb/modules/Clash/"
SCRIPTS_PATH="/data/adb/Box/scripts/"
NET_PATH="/data/misc/net"
CTR_PATH="/data/misc/net/rt_tables"
CONFIG_FILE="/data/adb/Box/clash/config.yaml"
BACKUP_FILE="/data/adb/Box/clash/subscribe_urls_backup.txt"

if [ "$BOOTMODE" != true ]; then
  abort "Error: 请在 Magisk Manager / KernelSU Manager / APatch 中安装"
elif [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "Error: 请更新您的 KernelSU Manager 版本"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10683 ]; then
  service_dir="/data/adb/ksu/service.d"
else
  service_dir="/data/adb/service.d"
fi

if [ ! -d "$service_dir" ]; then
  mkdir -p "$service_dir"
fi
ui_print "- Updating..."
ui_print "- ————————————————"

extract_subscribe_urls() {
  if [ -f "$CONFIG_FILE" ]; then
    awk '/p: &p/,/}/' "$CONFIG_FILE" | grep -Eo 'url: ".*"' | sed -E 's/url: "(.*)"/\1/' > "$BACKUP_FILE"
    if [ -s "$BACKUP_FILE" ]; then
      echo "- 订阅地址 URL 已备份 txt"
    else
      echo "- 未找到目标 URL，请检查配置文件格式"
    fi
  else
    echo "- 配置文件不存在，无法提取订阅地址"
  fi
}

restore_subscribe_urls() {
  if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    URL=$(cat "$BACKUP_FILE" | tr -d '\n' | tr -d '\r')
    ESCAPED_URL=$(printf '%s\n' "$URL" | sed 's/[&/]/\\&/g')
    sed -i -E "/p: &p/{N;s|url: \".*\"|url: \"$ESCAPED_URL\"|}" "$CONFIG_FILE"
    echo "- 订阅地址已恢复至新文件中！"
  else
    echo "- 备份文件不存在或为空，无法恢复订阅地址。"
  fi
}

unzip -qo "${ZIPFILE}" -x 'META-INF/*' -d "$MODPATH"
if [ -d /data/adb/Box ]; then
  if [ -d /data/adb/Box/clash ]; then
    extract_subscribe_urls
    cp /data/adb/Box/clash/config.yaml /data/adb/Box/clash/config.yaml.bak
  fi
  if [ -d /data/adb/Box/scripts ]; then
    cp /data/adb/Box/scripts/box.config /data/adb/Box/scripts/box.config.bak
  fi
  ui_print "- 配置文件 config.yaml 已备份 bak"
  ui_print "- 用户配置 box.config 已备份 bak"

  rm -f "/data/adb/Box/clash/Gui Yacd: 获取面板.sh"
  rm -f "/data/adb/Box/clash/Gui Meta: 获取面板.sh"
  rm -f "/data/adb/Box/clash/Telegram chat.sh"
  rm -f "/data/adb/Box/clash/country.mmdb"
  rm -f "/data/adb/Box/clash/UpdateGeo.sh"
  rm -f "/data/adb/Box/clash/ASN.mmdb"
  rm -f "/data/adb/Box/clash/Update: 数据库.sh"
  rm -f "/data/adb/Box/clash/Telegram: 聊天组.sh"
  rm -f "/data/adb/Box/clash/Gui Meta: 在线面板.sh"
  rm -f "/data/adb/Box/clash/Gui Yacd: 在线面板.sh"
  rm -rf /data/adb/Box/clash/ui
  rm -rf /data/adb/Box/clash/dashboard
  cp -f "$MODPATH/Box/clash/config.yaml" /data/adb/Box/clash/
  cp -f "$MODPATH/Box/clash/enhanced_config.yaml" /data/adb/Box/clash/
  cp -f "$MODPATH/Box/clash/Toolbox.sh"
  cp -f "$MODPATH/Box/scripts/"* /data/adb/Box/scripts/
  rm -rf "$MODPATH/Box"
  
  restore_subscribe_urls
  ui_print "- 更新无需重启设备..."
else
  mv "$MODPATH/Box" /data/adb/
  ui_print "- Installing..."
  ui_print "- ————————————————"
  ui_print "- 安装完成 工作目录"
  ui_print "- data/adb/Box/"
  ui_print "- 安装无需重启设备..."
fi

if [ "$KSU" = true ]; then
  sed -i 's/name=Clash/name=ClashKernelSU/g' "$MODPATH/module.prop"
fi

if [ "$APATCH" = true ]; then
  sed -i 's/name=Clash/name=ClashAPatch/g' "$MODPATH/module.prop"
fi

# 设置权限
mkdir -p /data/adb/Box/bin/
mkdir -p /data/adb/Box/run/

rm -f customize.sh
mv -f "$MODPATH/Clash_service.sh" "$service_dir/"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive /data/adb/Box/ 0 3005 0755 0644
set_perm_recursive /data/adb/Box/scripts/ 0 3005 0755 0700
set_perm_recursive /data/adb/Box/bin/ 0 3005 0755 0700
set_perm "$service_dir/Clash_service.sh" 0 0 0700

chmod ugo+x /data/adb/Box/scripts/*

# 启动监控服务
for pid in $(pidof inotifyd); do
  if grep -q box.inotify /proc/${pid}/cmdline; then
    kill ${pid}
  fi
done

mkdir -p "$SURFING_PATH"
nohup inotifyd "${SCRIPTS_PATH}box.inotify" "$SURFING_PATH" > /dev/null 2>&1 &
nohup inotifyd "${SCRIPTS_PATH}net.inotify" "$NET_PATH" > /dev/null 2>&1 &
nohup inotifyd "${SCRIPTS_PATH}ctr.inotify" "$CTR_PATH" > /dev/null 2>&1 &