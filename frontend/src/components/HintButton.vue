<script setup>
import { ref } from "vue";

const open = ref(false);

const hints = [
  {
    number: "01",
    title: "Insecure Direct Object Reference — Delete",
    body: "Try deleting a file that doesn't belong to you. The DELETE endpoint accepts a file ID — does it verify you own that file before removing it?",
  },
  {
    number: "02",
    title: "Insecure Direct Object Reference — Download",
    body: "File IDs are sequential integers (1, 2, 3…). The download endpoint requires authentication, but does it verify the file belongs to you? Try requesting an ID you didn't upload.",
  },
  {
    number: "03",
    title: "Predictable Share Token",
    body: "Inspect a share link closely. What is the token based on? If you know approximately when a file was uploaded, can you enumerate share links for files you were never given access to?",
  },
];
</script>

<template>
  <!-- Trigger button -->
  <button
    @click="open = true"
    class="fixed bottom-6 right-6 w-12 h-12 rounded-full bg-accent hover:bg-accent-dark text-midnight font-bold text-lg shadow-lg shadow-accent/20 transition flex items-center justify-center z-50"
    title="Show hints"
  >
    ?
  </button>

  <!-- Modal overlay -->
  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4"
      @click.self="open = false"
    >
      <div class="bg-card border border-white/10 rounded-2xl w-full max-w-lg shadow-2xl">
        <!-- Header -->
        <div class="flex items-center justify-between px-6 py-5 border-b border-white/10">
          <div>
            <h2 class="text-white font-semibold text-lg">Exercise Hints</h2>
            <p class="text-slate-400 text-xs mt-0.5">OWASP A01 — Broken Access Control</p>
          </div>
          <button
            @click="open = false"
            class="text-slate-400 hover:text-white transition w-8 h-8 flex items-center justify-center rounded-lg hover:bg-white/10"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Hints -->
        <div class="p-6 space-y-4">
          <div
            v-for="hint in hints"
            :key="hint.number"
            class="flex gap-4 bg-surface/60 rounded-xl p-4 border border-white/5"
          >
            <span class="text-accent font-mono font-bold text-sm mt-0.5 shrink-0">{{ hint.number }}</span>
            <div>
              <p class="text-white text-sm font-medium mb-1">{{ hint.title }}</p>
              <p class="text-slate-400 text-sm leading-relaxed">{{ hint.body }}</p>
            </div>
          </div>
        </div>

        <div class="px-6 pb-5">
          <button
            @click="open = false"
            class="w-full bg-accent hover:bg-accent-dark text-midnight font-semibold py-2.5 rounded-lg transition text-sm"
          >
            Got it
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
