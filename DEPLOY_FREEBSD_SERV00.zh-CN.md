# GrokForge FreeBSD / SERV00 部署说明

本文面向你当前打包出来的单文件 FreeBSD 二进制：

- 文件：`grokforge-freebsd-amd64`
- 目标平台：`FreeBSD amd64`
- 部署场景：`SERV00` 或其他无 root / 普通用户可运行的 FreeBSD 主机

## 1. 部署结论

这个项目本身就是单文件部署设计：

- Go 主程序提供 API 和管理后台
- 前端页面已经嵌入二进制，不需要单独上传 `web/` 目录
- 默认数据库支持 `SQLite`
- 也支持 `PostgreSQL`
- 默认不依赖环境变量

也就是说，最小部署只需要：

1. 上传二进制文件
2. 准备一个 `config.toml`
3. 赋予执行权限并启动

## 2. 目录建议

建议在 SERV00 上使用一个独立目录，例如：

```text
~/grokforge/
├── grokforge-freebsd-amd64
├── config.toml
├── data/
├── logs/
└── run/
```

说明：

- `data/`：默认 SQLite 数据库、图片缓存、视频缓存都会写到这里
- `logs/`：默认日志文件会写到这里
- `run/`：如果你要自己放 PID 文件或启动脚本，可以放这里

## 3. 上传哪些文件

如果你使用当前已经构建好的单文件包，部署时至少上传：

1. `grokforge-freebsd-amd64`
2. `config.toml`

不需要上传：

- `web/`
- `internal/`
- `cmd/`
- Node.js 运行时
- Go 运行时

## 4. 启动前准备

### 4.1 设置可执行权限

```bash
chmod +x grokforge-freebsd-amd64
```

### 4.2 准备配置文件

最常见做法是在二进制同级目录放一个 `config.toml`：

```bash
./grokforge-freebsd-amd64 -config config.toml
```

如果你不传 `-config`，程序默认也会找当前工作目录下的 `config.toml`。

## 5. 最小可用配置

下面是最适合单机部署的最小配置：

```toml
[app]
app_key = "改成你自己的强密码"
host = "127.0.0.1"
port = 8080
db_driver = "sqlite"
db_path = "data/grokforge.db"
log_level = "info"
log_json = false
log_file_path = "logs/grokforge.log"

[proxy]
base_proxy_url = ""
```

说明：

- `app.app_key`：管理后台登录密码，生产环境必须改掉
- `app.host`：如果前面还有反向代理，建议先只监听 `127.0.0.1`
- `app.port`：程序监听端口
- `app.db_driver = "sqlite"`：使用 SQLite
- `app.db_path`：SQLite 数据库文件路径
- `app.log_file_path`：日志文件路径

## 6. 推荐生产配置

如果你打算长期跑，建议至少用下面这份：

```toml
[app]
app_key = "请替换成长度足够的强密码"
media_generation_enabled = true
temporary = true
disable_memory = true
stream = true
thinking = true
dynamic_statsig = true
custom_instruction = ""
filter_tags = ["xaiartifact", "xai:tool_usage_card", "grok:render"]
host = "127.0.0.1"
port = 8080
log_json = false
log_level = "info"
log_file_path = "logs/grokforge.log"
log_max_size_mb = 50
log_max_backups = 3
db_driver = "sqlite"
db_path = "data/grokforge.db"
request_timeout = 60
read_header_timeout = 10
max_header_bytes = 1048576
body_limit = 1048576
chat_body_limit = 10485760
admin_max_fails = 10
admin_window_sec = 300
global_rate_limit_rpm = 0
global_rate_limit_window = 60

[image]
nsfw = false
format = "base64"
blocked_parallel_attempts = 5
blocked_parallel_enabled = true

[proxy]
base_proxy_url = ""
asset_proxy_url = ""
cf_cookies = ""
skip_proxy_ssl_verify = false
enabled = false
flaresolverr_url = ""
refresh_interval = 3600
timeout = 300
cf_clearance = ""
browser = "chrome_146"
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"

[retry]
max_tokens = 5
per_token_retries = 2
reset_session_status_codes = [403]
retry_backoff_base = 0.5
retry_backoff_factor = 2.0
retry_backoff_max = 20.0
retry_budget = 60.0

[token]
fail_threshold = 5
usage_flush_interval_sec = 30
selection_algorithm = "high_quota_first"
max_inflight = 8
recent_use_penalty_sec = 15

[cache]
image_max_mb = 0
video_max_mb = 0
```

## 7. 配置文件各部分怎么理解

## 7.1 `[app]`

核心运行参数。

重点字段：

- `app_key`：管理后台密码
- `host`：监听地址
- `port`：监听端口
- `db_driver`：`sqlite` 或 `postgres`
- `db_path`：SQLite 文件路径
- `db_dsn`：PostgreSQL 连接串
- `log_file_path`：日志文件路径
- `request_timeout`：非大模型路由的默认超时
- `read_header_timeout`：请求头读取超时
- `chat_body_limit`：聊天接口最大 body，带 base64 图片时要重点关注

## 7.2 `[image]`

图片输出和图片阻断重试策略。

重点字段：

- `format = "base64"`：图片直接以内联 Base64 返回
- `format = "local_url"`：图片保存到本地缓存，再通过 `/api/files/image/...` 返回 URL

如果你在 SERV00 上不想额外占磁盘，优先用 `base64`。

如果你希望返回可访问的图片 URL，才用 `local_url`。

## 7.3 `[proxy]`

Grok 请求的代理、Cloudflare 相关参数。

只有你确实需要代理或自动刷新 CF 状态时才配置。

常见情况：

- 不需要代理：全部留空即可
- 需要 HTTP/SOCKS 代理：设置 `base_proxy_url`
- 需要 FlareSolverr：设置 `enabled = true` 和 `flaresolverr_url`

## 7.4 `[retry]`

请求失败后的重试策略。

默认值已经够用，一般不需要先改。

## 7.5 `[token]`

多 token 轮转、失败阈值、并发控制。

重点字段：

- `selection_algorithm`：选 token 的算法
- `max_inflight`：每个 token 最大并发数
- `recent_use_penalty_sec`：近期刚使用过的 token 降权窗口

## 7.6 `[cache]`

缓存大小限制。

- `image_max_mb = 0`：图片缓存不限制大小
- `video_max_mb = 0`：视频缓存不限制大小

如果你在 SERV00 配额有限，建议设置上限，例如：

```toml
[cache]
image_max_mb = 1024
video_max_mb = 4096
```

## 8. 是否需要环境变量

当前代码里没有发现必须依赖的环境变量。

程序的主要配置来源是：

1. 管理后台保存到数据库中的配置
2. `config.toml`
3. 程序内置默认值

也就是说，正常部署时：

- 不需要设置 `.env`
- 不需要导出 `APP_KEY`
- 不需要导出 `DATABASE_URL`

所有核心配置都走 `config.toml`。

## 9. 数据库怎么部署

支持两种方式：

1. SQLite
2. PostgreSQL

### 9.1 SQLite 部署

这是最简单的方案，最适合单实例 SERV00。

配置示例：

```toml
[app]
db_driver = "sqlite"
db_path = "data/grokforge.db"
```

特点：

- 不需要单独装数据库服务
- 程序首次启动会自动创建数据库目录
- 程序会自动跑表结构迁移
- 单实例部署最省事

注意事项：

- 适合单机单进程
- 不适合多个实例同时共享同一个 SQLite 文件
- 备份时直接备份 `data/` 即可

### 9.2 PostgreSQL 部署

如果你要更标准的生产环境，或者想把应用和数据库分离，可以用 PostgreSQL。

配置示例：

```toml
[app]
db_driver = "postgres"
db_dsn = "host=127.0.0.1 port=5432 user=grokforge password=yourpass dbname=grokforge sslmode=disable TimeZone=Asia/Shanghai"
```

特点：

- 更适合长期运行和更大的数据量
- 更方便备份、迁移和外部托管
- 更适合未来多实例扩展

注意事项：

- 数据库必须先准备好
- 启动时程序会自动连接并执行迁移
- `db_dsn` 要写完整可用连接串

## 10. 数据库相关的重要部署细节

这里有一个很重要的行为要说明：

- 程序会先根据 `config.toml` 打开数据库
- 打开数据库之后，才会从数据库里加载“管理面板保存的配置覆盖项”

这意味着：

- `db_driver`
- `db_path`
- `db_dsn`

这些数据库连接参数，应该以启动前的 `config.toml` 为准。

不要把“切换数据库”这件事理解成能在管理后台里热切换当前实例的数据库连接。部署时应先改好 `config.toml`，再重启程序。

## 11. 程序启动后会生成哪些文件

默认情况下，程序运行过程中会创建这些内容：

- `logs/grokforge.log`
- `data/grokforge.db`
- `data/tmp/image/`
- `data/tmp/video/`

说明：

- `logs/` 会自动创建
- `data/` 会自动创建
- 图片和视频缓存目录会在首次写入时自动创建

## 12. 图片和视频缓存怎么工作

当图片输出模式为 `local_url`，或者视频生成需要落盘时，程序会把文件写到：

```text
data/tmp/image/
data/tmp/video/
```

然后通过下面的路由提供访问：

- `/api/files/image/{name}`
- `/api/files/video/{name}`

如果你前面挂了反向代理，需要把这些路径正常转发给 GrokForge。

## 13. 建议的 SERV00 部署方式

最推荐的方式是：

1. 程序只监听 `127.0.0.1:8080`
2. 前面再挂你自己的反向代理或平台提供的映射入口
3. 管理后台密码必须改成强密码
4. 优先使用 SQLite，除非你明确需要 PostgreSQL

一个比较稳妥的 `config.toml` 例子：

```toml
[app]
app_key = "这里换成强密码"
host = "127.0.0.1"
port = 8080
db_driver = "sqlite"
db_path = "data/grokforge.db"
log_level = "info"
log_json = false
log_file_path = "logs/grokforge.log"

[image]
format = "base64"

[proxy]
base_proxy_url = ""
```

## 14. 启动命令

前台启动：

```bash
./grokforge-freebsd-amd64 -config config.toml
```

后台启动：

```bash
nohup ./grokforge-freebsd-amd64 -config config.toml > run/nohup.out 2>&1 &
```

查看日志：

```bash
tail -f logs/grokforge.log
```

如果你不想写文件日志，也可以把 `log_file_path` 设为空，只看标准输出。

## 15. 首次启动后怎么初始化

1. 启动程序
2. 打开管理后台
3. 用 `app_key` 登录
4. 添加 Grok Token
5. 按需创建 API Key
6. 用 OpenAI 兼容接口访问 `/v1/chat/completions`

## 16. 是否必须写 `app_key`

技术上不是必须。

如果 `app_key` 留空，程序会在启动时生成一个“仅当前进程有效的临时管理密码”，并写到日志里。

但生产环境不建议这么做，因为：

- 进程重启后会变
- 不适合长期管理
- 不方便自动化

所以正式部署时，建议始终手动配置固定 `app_key`。

## 17. 是否需要自定义模型文件

默认不需要。

程序内部已经嵌入了默认模型目录。

只有当你想完全替换默认模型目录时，才需要在 `config.toml` 里写：

```toml
[app]
models_file = "models.toml"
```

注意：

- `models_file` 是相对 `config.toml` 所在目录解析的
- 它会完全替换内置模型目录

## 18. 路径配置的建议

建议你把这些路径都写成相对当前部署目录的路径：

- `db_path = "data/grokforge.db"`
- `log_file_path = "logs/grokforge.log"`
- `models_file = "models.toml"`

这样迁移目录最简单。

需要注意的是：

- `models_file` 相对 `config.toml` 目录解析
- `db_path`、`log_file_path`、缓存目录本质上都依赖程序启动时的工作目录

所以最佳实践是：

1. 进入部署目录
2. 再执行二进制

例如：

```bash
cd ~/grokforge
./grokforge-freebsd-amd64 -config config.toml
```

## 19. 反向代理时要注意什么

如果你前面还有反向代理：

1. 把普通 HTTP 请求转发到 GrokForge
2. 保持 SSE 长连接可用
3. 不要拦 `/api/files/` 路径
4. 如果你要走图片本地 URL 模式，确保外部能访问 `/api/files/image/...`
5. 如果你要走视频功能，确保 `/api/files/video/...` 正常转发

## 20. 常见部署方案建议

### 20.1 最省事方案

- 单文件二进制
- SQLite
- `127.0.0.1:8080`
- 反向代理对外
- 图片使用 `base64`

适合：

- 个人使用
- SERV00
- 单实例

### 20.2 稍标准的生产方案

- 单文件二进制
- PostgreSQL
- `127.0.0.1:8080`
- 反向代理对外
- 日志写文件
- 图片按需使用 `local_url`

适合：

- 长期运行
- 数据量更大
- 要求更好备份和迁移

## 21. 故障排查

### 21.1 启动失败

先看：

- 标准输出
- `logs/grokforge.log`

常见原因：

- `config.toml` 写错
- `app_key` 留了默认值但你忘了改
- 端口被占用
- PostgreSQL DSN 错误
- 目录权限不够

### 21.2 管理后台打不开

检查：

- `host` 和 `port` 是否正确
- 反向代理是否转发到了正确端口
- 是否只监听在 `127.0.0.1`

### 21.3 图片 URL 打不开

检查：

- `image.format` 是否是 `local_url`
- `/api/files/` 是否被反向代理正确转发
- `data/tmp/image/` 是否可写

### 21.4 视频文件打不开

检查：

- `/api/files/video/` 路径是否正确转发
- `data/tmp/video/` 是否可写

## 22. 推荐的首次部署步骤

```bash
mkdir -p ~/grokforge
cd ~/grokforge

# 上传 grokforge-freebsd-amd64 和 config.toml 到这里
chmod +x grokforge-freebsd-amd64

mkdir -p data logs run

./grokforge-freebsd-amd64 -config config.toml
```

确认正常后再改成后台运行：

```bash
nohup ./grokforge-freebsd-amd64 -config config.toml > run/nohup.out 2>&1 &
```

## 23. 总结

这套程序的部署重点其实只有四件事：

1. 上传单文件二进制
2. 写好 `config.toml`
3. 选好数据库方案，SERV00 默认建议 SQLite
4. 确保 `data/`、`logs/`、缓存目录可写

默认情况下不需要环境变量，部署复杂度很低。
