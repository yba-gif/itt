/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#f0f4f9",
          500: "#1f3a5f",
          600: "#163052",
        },
      },
    },
  },
  plugins: [],
};
