import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{js,ts,jsx,tsx,mdx}", "./components/**/*.{js,ts,jsx,tsx,mdx}", "./lib/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        paper: {
          bg: "#f5f7f4",
          panel: "#ffffff",
          ink: "#17201d",
          muted: "#68736f",
          line: "#d9e0dc",
          green: "#246b5a",
          greenStrong: "#174d41",
          amber: "#b87524",
          blue: "#315f9d",
          softGreen: "#e4f1ec",
          softAmber: "#fbecd7",
          softBlue: "#e7eef8",
        },
      },
      fontFamily: {
        sans: ["Arial", "Hiragino Sans", "Yu Gothic", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
