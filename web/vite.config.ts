/// <reference types="vitest" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

// GitHub Pages de projeto é servido em /<repo>/. Ajuste se o repo mudar.
const base = "/lift-plus/";

export default defineConfig({
  base,
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["apple-touch-icon.png", "favicon.svg"],
      manifest: {
        name: "Lift+",
        short_name: "Lift+",
        description: "Controle de treino de academia, offline-first.",
        start_url: base,
        scope: base,
        display: "standalone",
        background_color: "#0b0b0f",
        theme_color: "#0b0b0f",
        icons: [
          { src: "pwa-192x192.png", sizes: "192x192", type: "image/png" },
          { src: "pwa-512x512.png", sizes: "512x512", type: "image/png" },
          {
            src: "pwa-512x512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,svg,png,ico,woff2}"],
      },
    }),
  ],
  test: {
    environment: "node",
    globals: true,
    include: ["src/**/*.test.ts"],
  },
});
