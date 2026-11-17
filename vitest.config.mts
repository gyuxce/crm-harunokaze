import { defineConfig } from 'vitest/config'

// Unit test untuk logika murni di src/lib (tanpa DOM / React), jadi environment `node`.
export default defineConfig({
  resolve: { tsconfigPaths: true }, // alias "@/..." dari tsconfig.json
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
})
