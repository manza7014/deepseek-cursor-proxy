#!/bin/bash
#
# DeepSeek Cursor Proxy 启动/停止/自启管理脚本
# Usage: ./deepseek-cursor-proxy.sh [start|stop|status|restart|enable|disable]
#

PROXY_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_LOG="/tmp/deepseek-proxy.log"
NGROK_LOG="/tmp/ngrok.log"

start() {
    echo "=== 启动 DeepSeek Cursor Proxy ==="

    PORT_PID=$(lsof -ti :9000 2>/dev/null)
    if [ -n "$PORT_PID" ]; then
        if ! pgrep -f "deepseek_cursor_proxy.server" | grep -q "$PORT_PID"; then
            echo "  [!] 端口 9000 被残留进程占用 (PID: $PORT_PID)，正在释放..."
            kill -9 "$PORT_PID" 2>/dev/null
            sleep 0.5
        fi
    fi

    if pgrep -f "deepseek_cursor_proxy.server" > /dev/null 2>&1; then
        echo "  [✓] 代理已在运行"
    else
        cd "$PROXY_DIR" || exit 1
        nohup .venv/bin/python -m deepseek_cursor_proxy.server --no-ngrok --port 9000 > "$PROXY_LOG" 2>&1 &
        PROXY_PID=$!
        sleep 0.5
        if kill -0 "$PROXY_PID" 2>/dev/null; then
            echo "  [✓] 代理已启动 (PID: $PROXY_PID)"
        else
            echo "  [✗] 代理启动失败，错误日志："
            tail -5 "$PROXY_LOG"
            return 1
        fi
    fi

    if pgrep -x "ngrok" > /dev/null 2>&1; then
        echo "  [✓] ngrok 已在运行"
    else
        nohup ngrok http 9000 > "$NGROK_LOG" 2>&1 &
        echo "  [✓] ngrok 已启动 (PID: $!)"
    fi

    sleep 3
    status
}

stop() {
    echo "=== 停止 DeepSeek Cursor Proxy ==="

    if pgrep -f "deepseek_cursor_proxy.server" > /dev/null 2>&1; then
        pkill -f "deepseek_cursor_proxy.server"
        echo "  [✓] 代理已停止"
    else
        echo "  [-] 代理未运行"
    fi

    if pgrep -x "ngrok" > /dev/null 2>&1; then
        pkill -x ngrok
        echo "  [✓] ngrok 已停止"
    else
        echo "  [-] ngrok 未运行"
    fi
}

status() {
    echo ""
    echo "=== 运行状态 ==="

    if pgrep -f "deepseek_cursor_proxy.server" > /dev/null 2>&1; then
        echo "  代理: ✅ 运行中"
    else
        echo "  代理: ❌ 未运行"
    fi

    if pgrep -x "ngrok" > /dev/null 2>&1; then
        NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tunnels'][0]['public_url'])" 2>/dev/null)
        echo "  ngrok: ✅ 运行中 → $NGROK_URL"
    else
        echo "  ngrok: ❌ 未运行"
    fi
}

enable() {
    echo "=== 设置开机自启 ==="
    PLIST="$HOME/Library/LaunchAgents/com.deepseek.proxy.plist"
    if launchctl list com.deepseek.proxy &>/dev/null 2>&1; then
        echo "  [✓] 开机自启已启用"
    else
        launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null
        echo "  [✓] 开机自启已启用（下次登录自动启动）"
    fi
    echo "  也可手动运行: launchctl load ~/Library/LaunchAgents/com.deepseek.proxy.plist"
}

disable() {
    echo "=== 取消开机自启 ==="
    PLIST="$HOME/Library/LaunchAgents/com.deepseek.proxy.plist"
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null
    echo "  [✓] 开机自启已取消"
}

case "${1:-start}" in
    start)   start ;;
    stop)    stop ;;
    status)  status ;;
    restart) stop; sleep 1; start ;;
    enable)  enable ;;
    disable) disable ;;
    *)
        echo "用法: $0 {start|stop|status|restart|enable|disable}"
        exit 1
        ;;
esac
