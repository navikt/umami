# Umami Tracking Scripts

This directory contains the source files for our custom Umami tracking scripts. These are based on the [official Umami tracker](https://github.com/umami-software/umami/blob/master/src/tracker/index.js).

## Build Process

The scripts in this directory are **unminified source files**. They are automatically minified and deployed to CDN via the `push-to-cdn` workflow when changes are pushed to the `main` branch.

**Important:** The minified files in `public/sporing/` are git-ignored and generated during the build process. Never edit the minified files directly.

## Current Scripts

### `index.js` → `sporing.js`
The standard Umami tracker with no modifications. Reads the `data-host-url` attribute to determine the API endpoint.

**Usage:**
```html
<script 
  src="https://cdn.nav.no/team-researchops/sporing.js" 
  data-website-id="your-website-id"
  data-host-url="https://your-umami-instance.com"
></script>
```

### `sporing-dev.js` → `sporing-dev.js`
Development variant with hardcoded endpoint for testing.

**Modifications:**
- Hardcoded `hostUrl = "https://reops-event-proxy.ekstern.dev.nav.no"`

**Usage:**
```html
<script 
  src="https://cdn.nav.no/team-researchops/sporing-dev.js" 
  data-website-id="your-website-id"
></script>
```

## Legacy Scripts

The following scripts are automatically generated as **duplicates of `sporing.js`** to maintain backward compatibility during the phase-out period:

- `sporing-uten-uuid.js` (previously had UUID redaction)
- `sporing-uten-navident.js` (previously had NAV identifier redaction)
- `sporing-uten-veilederidentid.js` (previously had veileder ID redaction)
- `sporing-uten-uuid-og-navident.js` (previously had combined redactions)
- `umamisporing.js` (legacy variant)

**Note:** These files are now identical to `sporing.js`. The build script creates them automatically so existing implementations continue to work. Teams using these scripts should migrate to `sporing.js`.

## Local Development

Install dependencies:
```bash
npm install
```

Build minified scripts:
```bash
npm run build:tracker
```

This generates minified files in `public/sporing/` for local testing.

## Making Changes

1. Edit source files in `src/tracker/`
2. Test locally with `npm run build:tracker`
3. Commit only the source files (minified files are git-ignored)
4. Push to `main` - the workflow will build and deploy to CDN automatically
