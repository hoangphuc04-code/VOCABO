/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "sans-serif"],
      },
      colors: {
        primary: {
          DEFAULT: "#667eea",
          dark:    "#764ba2",
          light:   "#eef0ff",
        },
        success: "#06D6A0",
        warning: "#FFB703",
        danger:  "#EF233C",
      },
      backgroundImage: {
        "gradient-primary": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
      },
      boxShadow: {
        card:       "0 4px 24px rgba(102,126,234,0.12)",
        "card-hover": "0 12px 32px rgba(102,126,234,0.22)",
      },
      borderRadius: {
        "2xl": "16px",
        "3xl": "24px",
      },
    },
  },
  plugins: [],
};
