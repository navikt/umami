#!/usr/bin/env node
/**
 * Build script for tracker variants
 * Minifies the source trackers and outputs to public/sporing/
 */

const fs = require("fs");
const path = require("path");
const { minify } = require("terser");

const srcDir = path.join(__dirname, "..", "src", "tracker");
const outputDir = path.join(__dirname, "..", "public", "sporing");

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Scripts to build
const scripts = [
  { input: "sporing.js", output: "sporing.js" },
  { input: "sporing-uten-uuid.js", output: "sporing-uten-uuid.js" },
  // { input: "sporing.js", output: "sporing-uten-navident.js" },
  // { input: "sporing.js", output: "sporing-uten-veilederidentid.js" },
  // { input: "sporing.js", output: "sporing-uten-uuid-og-navident.js" },
  // { input: "sporing.js", output: "umamisporing.js" },
  // { input: "sporing.js", output: "sporing-navet5.js" },
  // { input: "sporing.js", output: "sporing-navet6.js" },
  { input: "sporing-dev.js", output: "sporing-dev.js" },
];

console.log("Building tracker scripts...\n");

async function buildScripts() {
  // Build main scripts
  for (const { input, output } of scripts) {
    const inputFile = path.join(srcDir, input);
    const outputFile = path.join(outputDir, output);

    if (!fs.existsSync(inputFile)) {
      console.log(`⚠ Skipping ${input} (not found)`);
      continue;
    }

    console.log(`Building ${output}...`);

    try {
      const code = fs.readFileSync(inputFile, "utf8");
      const result = await minify(code, {
        compress: {
          drop_console: false,
          drop_debugger: true,
        },
        mangle: true,
        format: {
          comments: false,
        },
      });

      if (result.error) {
        throw result.error;
      }

      fs.writeFileSync(outputFile, result.code);
      const stats = fs.statSync(outputFile);
      console.log(
        `✓ ${output} built successfully (${Math.round((stats.size / 1024) * 10) / 10} KB)`,
      );
    } catch (error) {
      console.error(`✗ Failed to build ${output}:`, error.message);
      process.exit(1);
    }
  }

  console.log("\n✓ Build complete!");
}

buildScripts().catch((error) => {
  console.error("Build failed:", error);
  process.exit(1);
});
