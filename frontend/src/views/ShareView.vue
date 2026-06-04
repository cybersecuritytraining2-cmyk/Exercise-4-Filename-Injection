<script setup>
import { ref, onMounted } from "vue";
import { useRoute } from "vue-router";
import axios from "axios";

const route = useRoute();
const state = ref("loading"); // loading | ready | error
const filename = ref("");
const blobUrl = ref("");

onMounted(async () => {
  try {
    const res = await axios.get(`/share/${route.params.token}`, {
      responseType: "blob",
    });
    const disposition = res.headers["content-disposition"] || "";
    const match = disposition.match(/filename="?([^";\n]+)"?/);
    filename.value = match ? match[1] : "download";
    blobUrl.value = URL.createObjectURL(res.data);
    state.value = "ready";
  } catch {
    state.value = "error";
  }
});

function triggerDownload() {
  const a = document.createElement("a");
  a.href = blobUrl.value;
  a.download = filename.value;
  a.click();
}
</script>

<template>
  <div class="min-h-screen bg-midnight flex flex-col items-center justify-center px-4">
    <!-- Logo -->
    <div class="flex items-center gap-2 mb-12">
      <div class="w-8 h-8 rounded-lg bg-accent flex items-center justify-center">
        <svg class="w-4 h-4 text-midnight" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
        </svg>
      </div>
      <span class="text-xl font-bold text-white tracking-tight">SwiftDrop</span>
    </div>

    <!-- Loading -->
    <div v-if="state === 'loading'" class="text-center">
      <div class="w-10 h-10 border-2 border-accent border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-slate-400 text-sm">Preparing your download…</p>
    </div>

    <!-- Ready -->
    <div v-else-if="state === 'ready'" class="bg-card border border-white/5 rounded-2xl p-10 text-center max-w-sm w-full shadow-2xl">
      <div class="w-16 h-16 rounded-2xl bg-accent/10 flex items-center justify-center mx-auto mb-5">
        <svg class="w-8 h-8 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m.75 12l3 3m0 0l3-3m-3 3v-6m-1.5-9H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        </svg>
      </div>
      <p class="text-white font-semibold mb-1 truncate px-2">{{ filename }}</p>
      <p class="text-slate-500 text-sm mb-6">Shared via SwiftDrop</p>
      <button
        @click="triggerDownload"
        class="w-full bg-accent hover:bg-accent-dark text-midnight font-semibold py-3 rounded-xl transition text-sm"
      >
        Download file
      </button>
    </div>

    <!-- Error -->
    <div v-else class="bg-card border border-white/5 rounded-2xl p-10 text-center max-w-sm w-full shadow-2xl">
      <div class="w-16 h-16 rounded-2xl bg-red-500/10 flex items-center justify-center mx-auto mb-5">
        <svg class="w-8 h-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
        </svg>
      </div>
      <p class="text-white font-semibold mb-1">Link not found</p>
      <p class="text-slate-400 text-sm">This share link may have expired or the file was deleted.</p>
      <RouterLink to="/login" class="mt-6 inline-block text-accent hover:text-accent-dark text-sm font-medium transition">
        Sign in to upload files →
      </RouterLink>
    </div>
  </div>
</template>
