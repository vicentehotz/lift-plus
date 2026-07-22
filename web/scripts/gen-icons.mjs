// Gera os PNGs do PWA a partir de assets/icon.svg (executar: npm run gen:icons).
// Mantém os binários fora do git; o CI regenera antes do build.
import sharp from "sharp";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const svg = readFileSync(resolve(root, "assets/icon.svg"));

const targets = [
  { file: "public/pwa-192x192.png", size: 192 },
  { file: "public/pwa-512x512.png", size: 512 },
  { file: "public/apple-touch-icon.png", size: 180 },
];

for (const { file, size } of targets) {
  await sharp(svg, { density: 384 })
    .resize(size, size)
    .png()
    .toFile(resolve(root, file));
  console.log(`gerado ${file} (${size}x${size})`);
}
