# TXPlayer

基于 **Electron + Vue 3 + Node.js** 的桌面音乐播放器，聚合网易云音乐、哔哩哔哩、QQ 音乐与本地音乐。

## 功能

- **多音源播放**：网易云音乐、B站视频（音画解析 / 清晰度切换）、QQ 音乐歌单导入、本地音乐文件夹扫描
- **账号体系**：网易云扫码/手机登录、B站扫码登录（解锁 1080P 及以上清晰度）
- **歌词体验**：黑胶唱片歌词页、逐行滚动跟随、翻译歌词、**桌面歌词**（透明置顶窗口，右键改字号/颜色）
- **播放核心**：队列管理、列表/单曲/随机循环、定时关闭、进度与状态记忆（重启恢复）
- **均衡器**：10 段增益、8 种预设、自定义调节
- **下载管理**：按音质选择下载，进度实时显示
- **界面**：深/浅色主题、封面动态取色、液态玻璃播放栏、自定义图标
- 搜索（网易云综合 / 歌单 / B站视频）、排行榜、歌手页、专辑页、每日推荐、私人 FM
- 系统托盘、关闭最小化到托盘、全局快捷键

## 目录结构

```
electron/   Electron 主进程（窗口、托盘、桌面歌词、下载、缩略图工具栏）
web/        Vue 3 前端（Vite + Pinia + Vue Router）
server/     Node/Express 后端（网易云 / B站 / QQ / 本地媒体接口）
```

## 开发运行

```bash
# 安装依赖（npm workspaces）
npm install

# 开发模式：后端 + 前端 + Electron
npm run dev            # 等价于分别启动 server 与 web，再由 electron 加载
```

常用命令：

```bash
npm --workspace web run build   # 构建前端
npm run electron:build          # 打包 Windows 安装包（electron-builder, NSIS）
```

## 技术要点

- 后端为纯本地服务（默认 `http://127.0.0.1:3000`），前端与 Electron 通过 HTTP/IPC 访问
- 音频使用 HTML `<audio>` + Web Audio API 实现均衡器；B站视频支持渐进式 MP4 与 DASH 探测
- 桌面歌词为独立 Electron 窗口，通过 IPC 与主进程同步样式和歌词文本

## 说明

- 本项目仅供学习交流，音乐版权归各平台所有，请勿用于商业用途
- 登录凭证仅保存在本机（`userData` 目录），不会上传任何服务器
