// 打包前准备脚本：将 server 代码连同完整 node_modules 复制到 build-temp/server
// 解决 npm workspaces hoisting 导致的依赖缺失问题
const { execSync } = require('child_process')
const fs = require('fs')
const path = require('path')

const src = path.join(__dirname, 'server')
const dest = path.join(__dirname, 'build-temp', 'server')

function copyFileSync(s, d) {
  fs.mkdirSync(path.dirname(d), { recursive: true })
  fs.copyFileSync(s, d)
}

function copyNonNodeModules(srcDir, destDir) {
  fs.mkdirSync(destDir, { recursive: true })
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    if (entry.name === 'node_modules') continue
    const srcPath = path.join(srcDir, entry.name)
    const destPath = path.join(destDir, entry.name)
    if (entry.isDirectory()) {
      copyNonNodeModules(srcPath, destPath)
    } else {
      copyFileSync(srcPath, destPath)
    }
  }
}

// 清理旧目录
if (fs.existsSync(dest)) {
  fs.rmSync(dest, { recursive: true, force: true })
}

console.log('[build-script] 1/3 复制 server 源代码（不含 node_modules）...')
copyNonNodeModules(src, dest)

console.log('[build-script] 2/3 复制 package.json 并安装生产依赖...')
// 复制 package.json 和 package-lock.json（如果有的话）
fs.copyFileSync(path.join(src, 'package.json'), path.join(dest, 'package.json'))
const srcLock = path.join(src, 'package-lock.json')
if (fs.existsSync(srcLock)) {
  fs.copyFileSync(srcLock, path.join(dest, 'package-lock.json'))
}

// 在 build-temp/server 中运行 npm install --omit=dev
// 由于 build-temp/server 不是 workspace 成员，所有依赖都会被安装到这个目录的 node_modules 中
console.log('[build-script] 执行 npm install --omit=dev (可能需要一些时间)...')
execSync('npm install --omit=dev', {
  cwd: dest,
  stdio: 'inherit',
  timeout: 120000
})

// 验证关键依赖存在
const nmPath = path.join(dest, 'node_modules')
const pkgCount = fs.readdirSync(nmPath).length
console.log(`[build-script] 3/3 完成！node_modules 已安装 (${pkgCount} 个顶层包)`)

// 验证 axios
const axiosPath = path.join(nmPath, 'axios')
if (!fs.existsSync(axiosPath)) {
  console.error('[build-script] 错误: axios 未安装!')
  process.exit(1)
}
console.log('[build-script] ✓ axios 已确认存在')