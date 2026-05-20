# DeepSeek Cursor Proxy 使用指南

> 解决 Cursor 中使用 DeepSeek 思考模型时 `reasoning_content` 缺失导致的 400 错误，通过代理 + ngrok 隧道实现 Cursor 与 DeepSeek API 的兼容。

---

## 架构说明

```
Cursor → ngrok (HTTPS) → Proxy (localhost:9000) → DeepSeek API
```

- **Proxy**：修复 `reasoning_content` 字段，使其兼容 DeepSeek 思考模式
- **ngrok**：将本地代理暴露为公共 HTTPS 地址，Cursor 要求非 localhost 的 API URL

---

## 安装与配置

### 1. 安装 ngrok

```bash
brew install ngrok
ngrok config add-authtoken 3DkW2e1LOTXymu6tAO84ARvqNPW_26V6bbtGiYm5xNJ8QqFHJ
```

> Authtoken 已配置完成，无需重复操作。

### 2. 克隆并安装代理

```bash
git clone https://github.com/yxlao/deepseek-cursor-proxy.git
cd deepseek-cursor-proxy
```

使用 uv 运行（推荐）：

```bash
# 如未安装 uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# 安装依赖并运行
uv run deepseek-cursor-proxy
```

首次运行会自动生成配置文件 `~/.deepseek-cursor-proxy/config.yaml`。

### 3. 配置文件说明

配置文件路径：`~/.deepseek-cursor-proxy/config.yaml`

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `base_url` | `https://api.deepseek.com` | DeepSeek API 地址 |
| `model` | `deepseek-v4-pro` | 默认模型（回退用） |
| `thinking` | `enabled` | 启用思考模式 |
| `reasoning_effort` | `max` | 思考强度 |
| `display_reasoning` | `true` | 在 Cursor 中显示思考过程 |
| `ngrok` | `true` | 是否自动启动 ngrok |
| `ngrok_url` | `null` | 固定 ngrok 域名（付费功能） |
| `port` | `9000` | 代理本地端口 |
| `verbose` | `false` | 调试日志开关 |
| `request_timeout` | `300` | 请求超时时间（秒） |

---

## 使用步骤

### Step 1: 启动 ngrok 隧道

```bash
ngrok http 9000
```

ngrok URL 已固定为 `https://immortal-hatbox-earthworm.ngrok-free.dev`，重启后不会变化。

### Step 2: 启动代理

```bash
cd /Users/liyongfeng/develop/work/deepseek-cursor-proxy

# 方式一：使用管理脚本（推荐）
./deepseek-cursor-proxy.sh start

# 方式二：直接后台运行
nohup .venv/bin/python -m deepseek_cursor_proxy.server --no-ngrok --port 9000 > /tmp/deepseek-proxy.log 2>&1 &
```

启动成功时会输出类似信息：

```
default_model: deepseek-v4-pro (thinking, max)
public_tunnel: off
local_base_url: http://127.0.0.1:9000/v1
api_base_url: http://127.0.0.1:9000/v1
```

### Step 3: 验证服务是否正常

```bash
# 验证本地代理
curl http://127.0.0.1:9000/v1/models

# 验证 ngrok 公共 URL
curl https://immortal-hatbox-earthworm.ngrok-free.dev/v1/models
```

两个命令均应返回 HTTP 200 及模型列表。

### Step 4: 在 Cursor 中配置自定义模型

打开 Cursor **Settings → Models → Add Custom Model**，填写：

| 字段 | 值 |
|------|-----|
| **Model** | `deepseek-v4-pro` |
| **API Key** | `sk-3d12cb96b2964457be60f34977b43e65` |
| **Base URL** | `https://immortal-hatbox-earthworm.ngrok-free.dev/v1` |

> 可选：可以添加 `deepseek-v4-flash` 模型，API Key 和 Base URL 相同。

### Step 5: 开始使用

1. 在 Cursor 的模型选择器中选择 `deepseek-v4-pro`
2. 使用 Chat 或 Agent 模式发送消息
3. 可以看到 DeepSeek 的思考过程（以 `<think>` 标签显示）
4. 正常对话和代码生成功能可用

---

## 在 Cursor 中使用

### 切换模型

- 在 Chat/Agent 界面顶部选择 `deepseek-v4-pro`
- macOS 快捷键 `Cmd+Shift+0` 可快速切换自定义 API 开关

### 注意事项

- **思考过程显示**：思考过程会以 `<think>...</think>` 标签形式显示在 Cursor 中，如果觉得干扰，可在配置中关闭：

```yaml
display_reasoning: false
```

- **上下文缓存**：代理会自动缓存 `reasoning_content`，避免重复消耗 token。切换对话或重启代理后首次请求可能需要多等待几秒

- **模型选择**：根据需求选择：
  - `deepseek-v4-pro`：更强推理能力，适合复杂任务
  - `deepseek-v4-flash`：更快响应，适合简单对话

---

## 快速管理（推荐）

项目目录下提供了 `deepseek-cursor-proxy.sh` 管理脚本，一条命令管理所有服务：

```bash
cd /Users/liyongfeng/develop/work/deepseek-cursor-proxy

# 启动（同时启动代理 + ngrok）
./deepseek-cursor-proxy.sh start

# 查看运行状态
./deepseek-cursor-proxy.sh status

# 停止
./deepseek-cursor-proxy.sh stop

# 重启
./deepseek-cursor-proxy.sh restart
```

输出示例：

```
=== 运行状态 ===
  代理: ✅ 运行中
  ngrok: ✅ 运行中 → https://immortal-hatbox-earthworm.ngrok-free.dev
```

> 代理的 PID、日志路径等无需关心，脚本已自动管理。

---

## 开机自启（推荐）

设置后每次登录自动启动代理和 ngrok，无需手动操作。

### 启用开机自启

```bash
cd /Users/liyongfeng/develop/work/deepseek-cursor-proxy
./deepseek-cursor-proxy.sh enable
```

### 取消开机自启

```bash
./deepseek-cursor-proxy.sh disable
```

### 手动管理（备选）

如果 `./deepseek-cursor-proxy.sh enable` 在终端中提示加载失败，请手动执行：

```bash
launchctl load ~/Library/LaunchAgents/com.deepseek.proxy.plist
```

取消自启：

```bash
launchctl unload ~/Library/LaunchAgents/com.deepseek.proxy.plist
```

---

## 原始管理命令

如果不想使用 `deepseek-cursor-proxy.sh`，也可以直接使用以下命令：

### 查看运行状态

```bash
# 查看代理进程
ps aux | grep deepseek_cursor_proxy

# 查看 ngrok 进程
ps aux | grep ngrok

# 查看代理日志
cat /tmp/deepseek-proxy.log

# 查看 ngrok 隧道状态（通过 API）
curl http://127.0.0.1:4040/api/tunnels
```

### 停止服务

```bash
# 停止代理
lsof -ti :9000 | xargs kill

# 停止 ngrok
pkill ngrok
```

### 后台启动

```bash
# 启动代理
cd /Users/liyongfeng/develop/work/deepseek-cursor-proxy
nohup .venv/bin/python -m deepseek_cursor_proxy.server --no-ngrok --port 9000 > /tmp/deepseek-proxy.log 2>&1 &

# 启动 ngrok
nohup ngrok http 9000 > /tmp/ngrok.log 2>&1 &
```

---

## 注意事项

### 1. ngrok 域名

ngrok 域名 `https://immortal-hatbox-earthworm.ngrok-free.dev` 已固定，重启后不会变化。在 [ngrok Dashboard](https://dashboard.ngrok.com/) 中可以查看你的域名。

### 2. 代理端口冲突

如果 9000 端口被占用，可修改配置或使用其他端口：

```bash
# 使用其他端口启动
uv run deepseek-cursor-proxy --port 9001

# 或修改配置文件
# ~/.deepseek-cursor-proxy/config.yaml
port: 9001
```

### 3. 第一个请求可能较慢

首次启动代理后，第一个请求需要初始化缓存，响应时间可能较长。后续请求会利用缓存加速。

### 4. Token 消耗

思考模式会消耗较多 token（显示为 reasoning tokens），注意监控 DeepSeek API 使用量。

### 5. 清除推理缓存

如果需要清除缓存的 `reasoning_content`：

```bash
cd /Users/liyongfeng/develop/work/deepseek-cursor-proxy
uv run deepseek-cursor-proxy --clear-reasoning-cache
```

### 6. 调试模式

遇到问题时开启 verbose 日志：

```bash
uv run deepseek-cursor-proxy --verbose
```

---

## 常见问题

### Q: 连接错误 `Provider returned error`

确保 ngrok 服务正常运行，且 Cursor 中的 Base URL 与 ngrok 分配的 URL 一致。

### Q: 代理启动失败 `Address already in use`

端口被占用，结束占用进程或更换端口：

```bash
lsof -ti :9000 | xargs kill -9
```

### Q: ngrok 隧道指向错误的端口

检查 ngrok 启动命令，确保 `ngrok http 9000` 中的端口与代理端口一致。

### Q: Cursor 报错 `reasoning_content must be passed back`

代理未正常工作。检查代理进程是否在运行，以及是否需要更新代理版本。

---

## 参考链接

- [DeepSeek Cursor Proxy GitHub](https://github.com/yxlao/deepseek-cursor-proxy)
- [DeepSeek API 文档 - 思考模式](https://api-docs.deepseek.com/guides/thinking_mode)
- [ngrok 官网](https://ngrok.com/)
