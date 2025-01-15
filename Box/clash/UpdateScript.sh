#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "请设置以 Root 用户运行"
    exit 1
fi

MODULE_PATH="/data/adb/modules/Clash"
if [ ! -d "$MODULE_PATH" ]; then
    echo "当前未安装 Clash 模块"
    exit 1
fi

CURRENT_VERSION="v2"
echo ""
echo "Version：$CURRENT_VERSION"
echo "以下将获取 GitHub main 最新提交！"
echo ""

UPDATESCRIPT_FILE="/data/adb/Box/clash/UpdateScript.sh"
GITHUB_REPO="XiaoA-qwq/Clash"
SCRIPTS_PATH="Box/scripts"
CLASH_PATH="Box/clash"
LOCAL_SCRIPTS_DIR="/data/adb/Box/scripts"
LOCAL_CLASH_DIR="/data/adb/Box/clash"
CONFIG_FILE="$LOCAL_CLASH_DIR/config.yaml"
BACKUP_FILE="$LOCAL_CLASH_DIR/subscribe_urls_backup.txt"
UPDATESCRIPT_URL="https://raw.githubusercontent.com/MoGuangYu/Clash/main/Box/clash/UpdateScript.sh"

get_remote_version() {
    remote_content=$(curl -s --connect-timeout 3 "$UPDATESCRIPT_URL")
    if [ $? -ne 0 ]; then
        echo "无法连接到 GitHub！"
        return 1
    fi
    remote_version=$(echo "$remote_content" | grep -Eo 'CURRENT_VERSION="v[0-9]+\.[0-9]+"' | head -1 | cut -d'=' -f2 | tr -d '"')
    if [ -z "$remote_version" ]; then
        echo "无法获取远程版本信息！"
        return 1
    fi
    echo "$remote_version"
    return 0
}

check_version() {
    remote_version=$(get_remote_version)
    if [ $? -ne 0 ]; then
        return
    fi

    if [ "$(echo "$remote_version" | cut -d'v' -f2)" != "$(echo "$CURRENT_VERSION" | cut -d'v' -f2)" ]; then
        echo "当前脚本版本: $CURRENT_VERSION"
        echo "最新脚本版本: $remote_version"
        echo "是否更新脚本？回复y/n"
        read -r update_confirmation
        if [ "$update_confirmation" = "y" ]; then
            echo "↴"
            echo "正在从 GitHub 下载最新版本..."
            curl -L -o "$UPDATESCRIPT_FILE" "$UPDATESCRIPT_URL"
            if [ $? -ne 0 ]; then
                echo "下载失败，请检查网络连接是否能正常访问 GitHub！"
                exit 1
            fi
            chmod 0644 "$UPDATESCRIPT_FILE"
            echo "正在运行最新版本的脚本..."
            exec sh "$UPDATESCRIPT_FILE"
            exit 0
        else
            echo "↴"
            echo "更新取消"
            echo "继续使用当前脚本！"
        fi
    else
        echo "当前已是最新版本: $CURRENT_VERSION"
    fi
}
check_version

FILES=(
    "$SCRIPTS_PATH/box.config|$LOCAL_SCRIPTS_DIR/box.config|backup"
    "$SCRIPTS_PATH/box.inotify|$LOCAL_SCRIPTS_DIR/box.inotify"
    "$SCRIPTS_PATH/box.service|$LOCAL_SCRIPTS_DIR/box.service"
    "$SCRIPTS_PATH/box.tproxy|$LOCAL_SCRIPTS_DIR/box.tproxy"
    "$SCRIPTS_PATH/ctr.inotify|$LOCAL_SCRIPTS_DIR/ctr.inotify"
    "$SCRIPTS_PATH/ctr.utils|$LOCAL_SCRIPTS_DIR/ctr.utils"
    "$SCRIPTS_PATH/net.inotify|$LOCAL_SCRIPTS_DIR/net.inotify"
    "$SCRIPTS_PATH/start.sh|$LOCAL_SCRIPTS_DIR/start.sh"
    "$CLASH_PATH/config.yaml|$LOCAL_CLASH_DIR/config.yaml|backup"
)

LOCAL_SHA_DIR="/data/adb/Box/variab/sha_cache"
mkdir -p "$LOCAL_SHA_DIR"

get_file_commit_info() {
    file_path="$1"
    commit_info=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/commits?path=$file_path" | grep -E '"message":' | head -1 | cut -d '"' -f4)
    if [ -z "$commit_info" ]; then
        echo "无法获取Git $file_path 的提交信息！"
        return 1
    fi
    echo "$commit_info"
    return 0
}

get_file_commit_sha() {
    file_path="$1"
    latest_sha=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/commits?path=$file_path" | grep '"sha"' | head -1 | cut -d '"' -f4)
    if [ -z "$latest_sha" ]; then
        echo "无法获取Git $file_path 的最新提交信息！"
        return 1
    fi
    echo "$latest_sha"
    return 0
}

backup_file() {
    local_file="$1"
    if [ -f "$local_file" ]; then
        backup_file="${local_file}.bak"
        cp "$local_file" "$backup_file"
        echo "↴"
        echo "Backup >>> $backup_file"
    fi
}

extract_subscribe_urls() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "Subscribe Backup >>> $BACKUP_FILE"
        awk '/proxy-providers:/,/^proxies:/' "$CONFIG_FILE" | grep -Eo "url: \".*\"" | sed -E 's/url: "(.*)"/\1/' > "$BACKUP_FILE"
        echo "备份完成"
    else
        echo "文件不存在，无法提取订阅地址"
    fi
}

check_and_update_files() {
    for file_entry in "${FILES[@]}"; do
        IFS='|' read -r file_path local_path need_backup <<< "$file_entry"
        local_sha_file="$LOCAL_SHA_DIR/$(basename "$local_path")_sha"
        latest_sha=$(get_file_commit_sha "$file_path")
        if [ $? -ne 0 ]; then
            continue
        fi

        if [ -f "$local_sha_file" ]; then
            current_sha=$(cat "$local_sha_file")
            if [ "$latest_sha" = "$current_sha" ]; then
                echo "local $(basename "$local_path") >>> Git latest"
                echo ""
                continue
            fi
        fi

        echo "Git main $(basename "$local_path") Updates"
        
        commit_info=$(get_file_commit_info "$file_path")
        #echo "——————————"
        echo "Commits：$commit_info"
        echo "——————————"
        echo "Sync？(y/n)"
        
        read -r user_response
        if [ "$user_response" != "y" ]; then
            echo "↴"
            echo "Skip"
            echo ""
            continue
        fi

        if [ "$need_backup" = "backup" ]; then
            backup_file "$local_path"
            if [ "$local_path" = "$CONFIG_FILE" ]; then
                extract_subscribe_urls
            fi
        fi

        echo "↴"
        echo "Downloading..."
        raw_url="https://raw.githubusercontent.com/$GITHUB_REPO/main/$file_path"
        curl -L -o "$local_path" "$raw_url"
        if [ $? -ne 0 ]; then
            echo "下载失败，请检查网络连接！"
            continue
        fi

        echo "更新完成✓"
        echo ""
        echo "$latest_sha" > "$local_sha_file"
    done
}

check_and_update_files

echo "检测已完毕..."
exit 0