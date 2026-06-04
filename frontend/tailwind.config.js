/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{vue,js}"],
  theme: {
    extend: {
      colors: {
        midnight: "#0f0f1a",
        surface: "#1a1a2e",
        card: "#16213e",
        accent: "#00d4aa",
        "accent-dark": "#00a888",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
};
