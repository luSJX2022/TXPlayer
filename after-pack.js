// electron-builder afterPack 钩子
// 在打包 win-unpacked 完成后、创建安装包之前，将 node_modules 复制到 resources/server/
const fs = require('fs')
const path = require('path')

exports.default = async function afterPack(context) {
  // context.appOutDir = release2/win-unpacked
  const serverDir = path.join(context.appOutDir, 'resources', 'server')
  const srcNm = path.join(process.cwd(), 'build-temp', 'server', 'node_modules')
  const destNm = path.join(serverDir, 'node_modules')

  if (!fs.existsSync(srcNm)) {
    console.warn('[afterPack] build-temp/server/node_modules 不存在，跳过复制')
    return
  }

  if (!fs.existsSync(serverDir)) {
    console.warn('[afterPack] resources/server 目录不存在，跳过复制')
    return
  }

  function copyDirSync(srcDir, destDir) {
    fs.mkdirSync(destDir, { recursive: true })
    for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
      const srcPath = path.join(srcDir, entry.name)
      const destPath = path.join(destDir, entry.name)
      if (entry.isDirectory()) {
        copyDirSync(srcPath, destPath)
      } else {
        fs.copyFileSync(srcPath, destPath)
      }
    }
  }

  console.log('[afterPack] 正在复制 node_modules 到 resources/server/ ...')
  copyDirSync(srcNm, destNm)
  const count = fs.readdirSync(destNm).length
  console.log(`[afterPack] 完成！已复制 ${count} 个包`)
}
