<script setup>
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/auth.js";
import { listFiles, uploadFile, downloadFile, deleteFile } from "@/services/api.js";
import HintButton from "@/components/HintButton.vue";

const router = useRouter();
const auth = useAuthStore();

const files = ref([]);
const uploading = ref(false);
const dragOver = ref(false);
const uploadError = ref("");
const copiedId = ref(null);

onMounted(loadFiles);

async function loadFiles() {
  const { data } = await listFiles();
  files.value = data;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function formatDate(iso) {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function onDragOver(e) {
  e.preventDefault();
  dragOver.value = true;
}

function onDragLeave() {
  dragOver.value = false;
}

function onDrop(e) {
  e.preventDefault();
  dragOver.value = false;
  const file = e.dataTransfer.files[0];
  if (file) upload(file);
}

function onFileInput(e) {
  const file = e.target.files[0];
  if (file) upload(file);
  e.target.value = "";
}

async function upload(file) {
  uploadError.value = "";
  uploading.value = true;
  const form = new FormData();
  form.append("file", file);
  try {
    await uploadFile(form);
    await loadFiles();
  } catch (e) {
    uploadError.value = e.response?.data?.error || "Upload failed.";
  } finally {
    uploading.value = false;
  }
}

async function download(file) {
  const { data, headers } = await downloadFile(file.id);
  const disposition = headers["content-disposition"] || "";
  const match = disposition.match(/filename="?([^";\n]+)"?/);
  const filename = match ? match[1] : file.filename;
  const url = URL.createObjectURL(data);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

async function remove(file) {
  await deleteFile(file.id);
  files.value = files.value.filter((f) => f.id !== file.id);
}

async function copyShareLink(file) {
  const url = `${window.location.origin}/share/${file.share_token}`;
  await navigator.clipboard.writeText(url);
  copiedId.value = file.id;
  setTimeout(() => (copiedId.value = null), 2000);
}

function logout() {
  auth.logout();
  router.push("/login");
}
</script>

<template>
  <div class="min-h-screen bg-midnight">
    <!-- Nav -->
    <nav class="border-b border-white/5 bg-surface/50 backdrop-blur-sm sticky top-0 z-40">
      <div class="max-w-4xl mx-auto px-6 h-14 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="w-7 h-7 rounded-md bg-accent flex items-center justify-center">
            <svg class="w-4 h-4 text-midnight" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
          </div>
          <span class="text-white font-semibold tracking-tight">SwiftDrop</span>
        </div>
        <div class="flex items-center gap-4">
          <span class="text-slate-400 text-sm hidden sm:block">{{ auth.user?.name }}</span>
          <button
            @click="logout"
            class="text-slate-400 hover:text-white text-sm transition"
          >
            Sign out
          </button>
        </div>
      </div>
    </nav>

    <div class="max-w-4xl mx-auto px-6 py-10">
      <!-- Upload zone -->
      <div
        class="rounded-2xl border-2 border-dashed transition-colors p-12 text-center cursor-pointer mb-10"
        :class="dragOver ? 'border-accent bg-accent/5' : 'border-white/10 hover:border-white/20'"
        @dragover="onDragOver"
        @dragleave="onDragLeave"
        @drop="onDrop"
        @click="$refs.fileInput.click()"
      >
        <input ref="fileInput" type="file" class="hidden" @change="onFileInput" />

        <div v-if="uploading" class="flex flex-col items-center gap-3">
          <div class="w-10 h-10 border-2 border-accent border-t-transparent rounded-full animate-spin"></div>
          <p class="text-slate-300 text-sm font-medium">Uploading…</p>
        </div>

        <div v-else class="flex flex-col items-center gap-3">
          <div class="w-14 h-14 rounded-2xl bg-accent/10 flex items-center justify-center">
            <svg class="w-7 h-7 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
            </svg>
          </div>
          <div>
            <p class="text-white font-medium mb-1">Drop your file here, or <span class="text-accent">browse</span></p>
            <p class="text-slate-500 text-sm">Any file type supported</p>
          </div>
        </div>

        <div v-if="uploadError" class="mt-4 bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-2.5 text-red-400 text-sm">
          {{ uploadError }}
        </div>
      </div>

      <!-- File list -->
      <div>
        <h2 class="text-white font-semibold text-sm uppercase tracking-wider mb-4 opacity-50">Your files</h2>

        <div v-if="files.length === 0" class="text-center py-16 text-slate-500">
          <svg class="w-10 h-10 mx-auto mb-3 opacity-40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <p class="text-sm">No files yet. Upload something above.</p>
        </div>

        <div v-else class="space-y-3">
          <div
            v-for="file in files"
            :key="file.id"
            class="bg-card border border-white/5 rounded-xl px-5 py-4 flex items-center gap-4 hover:border-white/10 transition group"
          >
            <!-- Icon -->
            <div class="w-10 h-10 rounded-lg bg-surface flex items-center justify-center shrink-0">
              <svg class="w-5 h-5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              </svg>
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <p class="text-white text-sm font-medium truncate">{{ file.filename }}</p>
              <p class="text-slate-500 text-xs mt-0.5">{{ formatSize(file.size) }} · {{ formatDate(file.uploaded_at) }} · <span class="font-mono text-slate-600">ID: {{ file.id }}</span></p>
            </div>

            <!-- Actions -->
            <div class="flex items-center gap-1 shrink-0">
              <!-- Download -->
              <button
                @click="download(file)"
                class="text-slate-400 hover:text-white transition p-2 rounded-lg hover:bg-white/5"
                title="Download"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                </svg>
              </button>

              <!-- Share -->
              <button
                @click="copyShareLink(file)"
                class="text-slate-400 hover:text-accent transition p-2 rounded-lg hover:bg-white/5"
                :title="copiedId === file.id ? 'Copied!' : 'Copy share link'"
              >
                <svg v-if="copiedId !== file.id" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                </svg>
                <svg v-else class="w-4 h-4 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </button>

              <!-- Delete -->
              <button
                @click="remove(file)"
                class="text-slate-400 hover:text-red-400 transition p-2 rounded-lg hover:bg-white/5"
                title="Delete"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <HintButton />
  </div>
</template>
