import axios from "axios";
import { useAuthStore } from "@/stores/auth.js";
import router from "@/router/index.js";

const http = axios.create({ baseURL: "/api" });

http.interceptors.request.use((config) => {
  const auth = useAuthStore();
  if (auth.token) {
    config.headers.Authorization = `Bearer ${auth.token}`;
  }
  return config;
});

http.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      useAuthStore().logout();
      router.push("/login");
    }
    return Promise.reject(err);
  }
);

export const register = (name, email, password) =>
  http.post("/auth/register", { name, email, password });

export const login = (email, password) =>
  http.post("/auth/login", { email, password });

export const listFiles = () => http.get("/files");

export const uploadFile = (formData) => http.put("/files", formData);

export const downloadFile = (id) =>
  http.get(`/files/${id}`, { responseType: "blob" });

export const deleteFile = (id) => http.delete(`/files/${id}`);
