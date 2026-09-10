<script setup lang="ts">
import { useEqualizerStore, PRESET_NAMES } from '@/stores/equalizer'

defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ (e: 'update:modelValue', v: boolean): void }>()

const eq = useEqualizerStore()

function formatFreq(f: number): string {
  return f < 1000 ? String(f) : (f / 1000).toFixed(f % 1000 === 0 ? 0 : 1) + 'k'
}

function formatGain(dB: number): string {
  const s = dB.toFixed(1)
  return (dB >= 0 ? '+' : '') + s + ' dB'
}

function close() {
  eq.close()
  emit('update:modelValue', false)
}
</script>

<template>
  <Transition name="queue-slide">
    <div v-if="modelValue" class="eq-overlay" @click.self="close">
      <div class="eq-panel">
        <div class="eq-head">
          <h3 class="eq-title">均衡器</h3>
          <div class="eq-head-actions">
            <label class="eq-toggle" title="启用/关闭">
              <span class="toggle-label">{{ eq.enabled ? '开' : '关' }}</span>
              <button class="switch" :class="{ on: eq.enabled }" @click="eq.toggle()">
                <span class="knob" />
              </button>
            </label>
            <button class="close-btn" title="关闭" @click="close">✕</button>
          </div>
        </div>

        <div class="eq-body">
          <!-- 预置音效 -->
          <div class="eq-presets">
            <button
              v-for="name in PRESET_NAMES"
              :key="name"
              class="preset-btn"
              :class="{ active: eq.preset === name }"
              @click="eq.applyPreset(name)"
            >
              {{ name }}
            </button>
          </div>

          <!-- 频段滑块 -->
          <div class="eq-bands">
            <div v-for="(b, idx) in eq.bands" :key="b.freq" class="eq-band">
              <span class="eq-label">{{ formatFreq(b.freq) }}</span>
              <input
                type="range"
                class="eq-slider"
                min="-12"
                max="12"
                step="0.5"
                :value="b.gain"
                :title="formatFreq(b.freq) + 'Hz ' + formatGain(b.gain)"
                @input="eq.setBandGain(idx, Number(($event.target as HTMLInputElement).value))"
              />
              <span class="eq-value" :class="{ minus: b.gain < 0, plus: b.gain > 0 }">
                {{ formatGain(b.gain) }}
              </span>
            </div>
          </div>

          <button class="reset-btn" @click="eq.reset()">重置为默认</button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.eq-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 60;
  display: flex;
  justify-content: flex-end;
}
.eq-panel {
  width: 340px;
  max-width: 90vw;
  height: 100%;
  background: var(--bg-elev);
  border-left: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  box-shadow: -8px 0 30px rgba(0, 0, 0, 0.4);
  transition: transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.eq-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 20px 16px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.eq-title {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
}
.eq-head-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.eq-toggle {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
}
.toggle-label {
  font-size: 12px;
  color: var(--text-dim);
}
/* switch — 复用全局开关样式 */
.switch {
  position: relative;
  width: 44px;
  height: 24px;
  border-radius: 12px;
  background: var(--bg-hover);
  border: 1px solid var(--border);
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.2s;
}
.switch .knob {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--text-dim);
  transition: all 0.2s;
}
.switch.on {
  background: var(--primary);
  border-color: var(--primary);
}
.switch.on .knob {
  left: 22px;
  background: #fff;
}
.close-btn {
  background: transparent;
  border: none;
  color: var(--text-dim);
  font-size: 18px;
  cursor: pointer;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.close-btn:hover {
  background: var(--bg-hover);
  color: var(--text);
}
.eq-body {
  flex: 1;
  overflow-y: auto;
  padding: 16px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
/* 预置选择 */
.eq-presets {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.preset-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 5px 12px;
  border-radius: 14px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.15s;
}
.preset-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.preset-btn.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
/* 频段 */
.eq-bands {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.eq-band {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
}
.eq-label {
  width: 36px;
  font-size: 11px;
  color: var(--text-dim);
  text-align: right;
  flex-shrink: 0;
}
.eq-slider {
  flex: 1;
  -webkit-appearance: none;
  appearance: none;
  height: 4px;
  background: var(--border);
  border-radius: 2px;
  outline: none;
  cursor: pointer;
}
.eq-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: var(--primary);
  cursor: pointer;
  border: 2px solid #fff;
}
.eq-slider::-moz-range-thumb {
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: var(--primary);
  cursor: pointer;
  border: 2px solid #fff;
}
.eq-value {
  width: 54px;
  font-size: 11px;
  color: var(--text-dim);
  flex-shrink: 0;
  text-align: left;
}
.eq-value.plus {
  color: #4ade80;
}
.eq-value.minus {
  color: #ff6b6b;
}
.reset-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 6px 0;
  border-radius: 8px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.15s;
}
.reset-btn:hover {
  border-color: #ff6b6b;
  color: #ff6b6b;
}
/* 滑入动画 */
.queue-slide-enter-active {
  transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.queue-slide-leave-active {
  transition: all 0.25s ease-in;
}
.queue-slide-enter-from .eq-panel {
  transform: translateX(100%);
}
.queue-slide-leave-to .eq-panel {
  transform: translateX(100%);
}
.queue-slide-enter-from,
.queue-slide-leave-to {
  opacity: 0;
  background: rgba(0, 0, 0, 0);
}
</style>