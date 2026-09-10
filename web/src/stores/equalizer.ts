import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { usePlayerStore } from './player'

/** 10段均衡器频点 */
const FREQS = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

/** 预置音效（各频段增益 dB，范围 -12 ~ +12） */
const PRESETS: Record<string, number[]> = {
  默认: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  流行: [-2, -1, 0, 2, 4, 3, 0, -2, -1, -1],
  摇滚: [4, 2, -1, -2, -1, 1, 3, 4, 3, 3],
  古典: [0, 0, 0, 0, 0, 0, -1, -2, -3, -3],
  爵士: [3, 2, 1, 0, 0, -1, -1, 0, 1, 2],
  电子: [4, 3, 0, -2, -4, -3, 0, 2, 3, 4],
  人声: [-3, -2, 0, 2, 3, 3, 2, 0, -1, -3]
}

export const PRESET_NAMES = Object.keys(PRESETS)

interface BandState {
  freq: number
  gain: number
}

interface EqPersist {
  enabled: boolean
  bands: BandState[]
  preset: string
}

export const useEqualizerStore = defineStore('equalizer', () => {
  const player = usePlayerStore()
  const enabled = ref(false)
  const bands = ref<BandState[]>(FREQS.map((f) => ({ freq: f, gain: 0 })))
  const preset = ref('默认')

  /** Web Audio API 实例，created lazily on first toggle */
  let ctx: AudioContext | null = null
  let sourceNode: MediaElementAudioSourceNode | null = null
  let filters: BiquadFilterNode[] = []

  const isEnabled = computed(() => enabled.value)

  // ----- 内部：创建/销毁音频处理链 -----
  function ensureContext() {
    if (ctx) return
    const audio = player.audio
    if (!audio) return
    ctx = new AudioContext()
    sourceNode = ctx.createMediaElementSource(audio)
    filters = FREQS.map((freq) => {
      const f = ctx!.createBiquadFilter()
      f.type = 'peaking'
      f.frequency.value = freq
      f.Q.value = 1.0
      f.gain.value = 0
      return f
    })
    // 串联：source → filters[0] → ... → filters[9] → destination
    let prev: AudioNode = sourceNode
    for (const f of filters) {
      prev.connect(f)
      prev = f
    }
    prev.connect(ctx.destination)
  }

  function applyAllGains() {
    // 统一更新所有滤波器增益
    for (let i = 0; i < bands.value.length; i++) {
      if (filters[i]) filters[i].gain.value = enabled.value ? bands.value[i].gain : 0
    }
  }

  // ----- 持久化 -----
  function loadState() {
    try {
      const raw = localStorage.getItem('eq_state')
      if (!raw) return
      const data: EqPersist = JSON.parse(raw)
      if (Array.isArray(data.bands) && data.bands.length === FREQS.length) {
        bands.value = data.bands
        if (data.preset) preset.value = data.preset
      }
      if (data.enabled) {
        // 恢复时仅恢复数值，不自动启用（AudioContext 需用户手势后创建）
        // 勾选开关时用户主动操作才创建 context
      }
    } catch {
      localStorage.removeItem('eq_state')
    }
  }

  function saveState() {
    try {
      localStorage.setItem(
        'eq_state',
        JSON.stringify({ enabled: enabled.value, bands: bands.value, preset: preset.value })
      )
    } catch {}
  }

  // ----- 初始化 -----
  function init() {
    loadState()
  }

  // ----- Actions -----

  function toggle() {
    enabled.value = !enabled.value
    if (enabled.value) {
      if (!ctx || ctx.state === 'closed') {
        try {
          ensureContext()
        } catch {
          enabled.value = false
          return
        }
      }
      if (ctx && ctx.state === 'suspended') ctx.resume()
    }
    applyAllGains()
    saveState()
    // 自定义预设时名称退出同步
    if (enabled.value) {
      const mat = presetNameFromBands(bands.value.map((b) => b.gain))
      if (mat !== preset.value) preset.value = mat
    }
  }

  function setBandGain(index: number, dB: number) {
    if (index < 0 || index >= FREQS.length) return
    dB = Math.min(12, Math.max(-12, Number(dB) || 0))
    bands.value[index].gain = dB
    if (filters[index]) filters[index].gain.value = enabled.value ? dB : 0
    preset.value = presetNameFromBands(bands.value.map((b) => b.gain))
    saveState()
  }

  function applyPreset(name: string) {
    const gains = PRESETS[name]
    if (!gains) return
    bands.value = FREQS.map((freq, i) => ({ freq, gain: gains[i] || 0 }))
    preset.value = name
    if (enabled.value) applyAllGains()
    saveState()
  }

  function reset() {
    applyPreset('默认')
    if (enabled.value) applyAllGains()
  }

  function close() {
    if (enabled.value) {
      enabled.value = false
      applyAllGains()
      saveState()
    }
  }

  // 判断 bands 是否匹配某个预置
  function presetNameFromBands(gains: number[]): string {
    for (const [name, g] of Object.entries(PRESETS)) {
      if (g.every((v, i) => Math.abs(v - gains[i]) < 0.01)) return name
    }
    return '自定义'
  }

  return {
    enabled,
    bands,
    preset,
    isEnabled,
    init,
    toggle,
    setBandGain,
    applyPreset,
    reset,
    close
  }
})