<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { login } from "@/services/api.js";
import { useAuthStore } from "@/stores/auth.js";

const router = useRouter();
const auth = useAuthStore();

const email = ref("");
const password = ref("");
const error = ref("");
const loading = ref(false);

async function handleSubmit() {
  error.value = "";
  loading.value = true;
  try {
    const { data } = await login(email.value, password.value);
    auth.setAuth(data.token, { name: data.name, email: data.email });
    router.push("/dashboard");
  } catch (e) {
    error.value = e.response?.data?.error || "Login failed. Please try again.";
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="min-h-screen bg-midnight flex items-center justify-center px-4">
    <div class="w-full max-w-md">
      <!-- Logo -->
      <div class="text-center mb-10">
        <div class="flex items-center justify-center gap-2 mb-3">
          <div class="w-9 h-9 rounded-lg bg-accent flex items-center justify-center">
            <svg class="w-5 h-5 text-midnight" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
          </div>
          <span class="text-2xl font-bold text-white tracking-tight">SwiftDrop</span>
        </div>
        <p class="text-slate-400 text-sm">Fast, secure file sharing</p>
      </div>

      <!-- Card -->
      <div class="bg-card rounded-2xl p-8 shadow-2xl border border-white/5">
        <h1 class="text-xl font-semibold text-white mb-1">Welcome back</h1>
        <p class="text-slate-400 text-sm mb-6">Sign in to your account</p>

        <form @submit.prevent="handleSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-300 mb-1.5">Email</label>
            <input
              v-model="email"
              type="email"
              required
              placeholder="you@example.com"
              class="w-full bg-surface border border-white/10 rounded-lg px-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:border-accent focus:ring-1 focus:ring-accent transition text-sm"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-300 mb-1.5">Password</label>
            <input
              v-model="password"
              type="password"
              required
              placeholder="••••••••"
              class="w-full bg-surface border border-white/10 rounded-lg px-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:border-accent focus:ring-1 focus:ring-accent transition text-sm"
            />
          </div>

          <div v-if="error" class="bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-3 text-red-400 text-sm">
            {{ error }}
          </div>

          <button
            type="submit"
            :disabled="loading"
            class="w-full bg-accent hover:bg-accent-dark text-midnight font-semibold py-2.5 rounded-lg transition text-sm disabled:opacity-60 disabled:cursor-not-allowed mt-2"
          >
            {{ loading ? "Signing in…" : "Sign in" }}
          </button>
        </form>

        <p class="text-center text-slate-400 text-sm mt-6">
          Don't have an account?
          <RouterLink to="/register" class="text-accent hover:text-accent-dark font-medium transition">Sign up</RouterLink>
        </p>
      </div>
    </div>
  </div>
</template>
