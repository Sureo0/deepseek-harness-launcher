# DeepSeek Harness 一键部署脚本(Windows)

[English](README.md) | 简体中文

仅需 2 个文件,即可在 Windows 上**零依赖**部署 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 。**不需要预装 Node.js / Git / pnpm,不污染系统,删除即卸载。**

## 快速开始

1. 把 2 个文件放入同一文件夹(路径别太深,例如 `D:\dsh`)

2. 双击 `setup_dsh.bat` —— 自动完成:下载便携 Node.js → 安装 pnpm → 获取 dsh 源码 → 安装依赖 → 全量构建 → 引导配置 API Key(首次约 10-30 分钟)

3. 双击 `start_dsh.bat` —— 启动 Web UI,自动打开浏览器 `http://127.0.0.1:3080`

日常使用只需要第 3 步。

## 原理:环境自动生成,整个删除即卸载

脚本运行后会在脚本目录自动创建 `env\` 虚拟环境,所有东西都在这个文件夹里:

```
你的文件夹\
├─ setup_dsh.bat       一键安装 / 更新 / 重建
├─ start_dsh.bat       一键启动
├─ README.md
└─ env\                 ← 自动生成,整个删除即完全卸载
   ├─ node\            便携 Node.js 22.19.0
   ├─ node_modules\    pnpm 11.7.0
   ├─ source\          dsh 源码(master 分支,已构建)
   │  └─ .env          API Key(本地生成,已被 .gitignore 排除)
   ├─ .pnpm-store\     依赖缓存(离线可复用)
   ├─ dsh-home\        所有 Harness 数据(会话、配置、插件)
   └─ ENV.bat          环境加载器(setup 自动生成,勿手改)
```

- **API Key 存哪**:`env\source\.env`,setup 时引导输入。dsh 的加载顺序:环境变量 > 启动目录 `.env` > `$DSH_HOME\.env`。
- **更新 dsh**:重跑 `setup_dsh.bat` —— git 模式自动 `git pull`;zip 模式询问后重新下载覆盖,然后增量装依赖 + 重新构建。
- **改源码跑实验**:直接在 `env\source` 里改,改完运行 `env\node_modules\.bin\pnpm.cmd run build`,再双击 `start_dsh.bat`。命令行模式:先 `call env\ENV.bat`,再 `cd env\source`,然后 `pnpm dsh --profile headless "任务"`。
- **换端口**:`start_dsh.bat <端口号>`;换监听地址:`dsh web --host <地址>`(`0.0.0.0` 会被拒绝,需配置受信主机)。
- **整个文件夹搬家**:脚本全部用相对路径(`%~dp0`),复制/移动后无需任何修改。
- **卸载**:删除本文件夹即可(数据全在 `env\` 里)。

## 常见问题

- **下载 Node / 源码失败**:Node 官方源失败会自动切 npmmirror;GitHub zip 下载失败请检查网络后重跑。国内环境依赖安装慢可先执行 `env\node\npm.cmd config set registry https://registry.npmmirror.com`(pnpm 也读 npm 配置)后重跑 setup。
- **pnpm install 报错**:多为网络问题,镜像配置见上;确认后重跑 setup。
- **构建失败**:先重跑一次(增量构建)。若报内存不足,按脚本提示设 `NODE_OPTIONS=--max-old-space-size=4096`。若报类型错误,说明上游 master 分支正处于开发中间态,等几小时再更新。
- **"The source tree is not built yet" / "The web UI is not built yet"**:说明构建产物缺失(各包的 `lib` 捆绑或 `apps\web\dist\index.html`),重跑 `setup_dsh.bat` 完成构建(已完成的步骤会自动跳过)。
- **浏览器没有自动打开**:手动访问 `http://127.0.0.1:3080` 即可。
- **磁盘占用**:源码 + 依赖 + 构建产物约 2-4 GB(`env\.pnpm-store` 是大头,删掉会变慢但安全)。

## 开源与隐私

- 本目录只包含**通用脚本,不含任何密钥**。你的 API Key 只在本地 `env\source\.env` 生成。
- 本项目是独立第三方工具，仅适用于 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)(MIT License)的 Windows 一键部署脚本，非官方产品。
- API 调用费用由使用者自己的 DeepSeek 账户承担。
