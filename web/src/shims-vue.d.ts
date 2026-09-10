/// <reference types="vite/client" />

// 版本号由 vite define 注入（见 vite.config.ts）
declare const __APP_VERSION__: string

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}
