#!/usr/bin/env node
/**
 * Build script for tracker variants.
 * All variants are generated from src/tracker/template.js with substitutions.
 */

const fs = require("fs");
const path = require("path");
const { minify } = require("terser");

const srcDir = path.join(__dirname, "..", "src", "tracker");
const outputDir = path.join(__dirname, "..", "public", "sporing");

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Substitution tokens in template.js:
//   __HOST_URL__       - JS expression for the endpoint host
//   __OPT_OUT_FILTERS__ - JS expression for opt-out-filters header value (or null)
//   __REDACT_UUID__    - JS function expression (identity fn or actual redactor)

const ENV_AWARE_HOST = `
  location.hostname.endsWith(".dev.nav.no")
    ? "https://reops-event-proxy.ekstern.dev.nav.no"
    : "https://reops-event-proxy.nav.no"
`.trim();

const DEV_HOST = `"https://reops-event-proxy.ekstern.dev.nav.no"`;

const IDENTITY_FN = `(s) => s`;

const REDACT_UUID_FN = `(str) => {
    return str
      ? str.replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, "[REDACTED-UUID]")
      : str;
  }`;

const OPT_OUT_FILTERS = `attr("data-opt-out-filters") || undefined`;
const NO_OPT_OUT_FILTERS = `undefined`;

const variants = [
  {
    output: "sporing.js",
    hostUrl: ENV_AWARE_HOST,
    redactUuid: IDENTITY_FN,
    optOutFilters: NO_OPT_OUT_FILTERS,
  },
  {
    output: "sporing-uten-uuid.js",
    hostUrl: ENV_AWARE_HOST,
    redactUuid: REDACT_UUID_FN,
    optOutFilters: NO_OPT_OUT_FILTERS,
  },
  {
    output: "sporing-dev.js",
    hostUrl: DEV_HOST,
    redactUuid: IDENTITY_FN,
    optOutFilters: OPT_OUT_FILTERS,
  },
];

const templateFile = path.join(srcDir, "template.js");

async function buildScripts() {
  if (!fs.existsSync(templateFile)) {
    console.error(`✗ Template not found: ${templateFile}`);
    process.exit(1);
  }

  const template = fs.readFileSync(templateFile, "utf8");

  console.log("Building tracker scripts...\n");

  for (const { output, hostUrl, redactUuid, optOutFilters } of variants) {
    const outputFile = path.join(outputDir, output);

    const code = template
      .replace("__HOST_URL__", hostUrl)
      .replace("__REDACT_UUID__", redactUuid)
      .replace("__OPT_OUT_FILTERS__", optOutFilters);

    console.log(`Building ${output}...`);

    try {
      const result = await minify(code, {
        compress: { drop_debugger: true },
        mangle: true,
        format: { comments: false },
      });

      if (result.error) throw result.error;

      fs.writeFileSync(outputFile, result.code);
      const stats = fs.statSync(outputFile);
      console.log(
        `✓ ${output} (${Math.round((stats.size / 1024) * 10) / 10} KB)`,
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
