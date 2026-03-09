# Tracking Script Comparison

## Key Differences Between Your Script and Official Umami Tracker

### 1. **Endpoint URL** ⚠️ CRITICAL
- **Your script**: `/api/send`
- **Official**: `__COLLECT_API_ENDPOINT__` (placeholder replaced during build)
- **Impact**: Your script has a hardcoded endpoint that may not match Umami's actual API endpoint

### 2. **Host URL Fallback**
- **Your script**: Falls back to empty string `""` 
- **Official**: Falls back to `__COLLECT_API_HOST__` (placeholder replaced during build)
- **Impact**: Your script may construct incorrect endpoint URLs

### 3. **URL Normalization** ⚠️ MAJOR
- **Your script**: NO normalization - directly assigns `new URL(...).toString()`
- **Official**: Has a dedicated `normalize()` function that:
  - Safely handles URL construction with try-catch
  - Only applies transformations if URL is valid
  - Returns raw value if URL parsing fails
- **Impact**: Your script may crash or behave unexpectedly with invalid URLs

### 4. **Fetch Credentials**
- **Your script**: Hardcoded to `"omit"`
- **Official**: Configurable via `data-fetch-credentials` attribute (defaults to `"omit"`)
- **Impact**: Cannot customize credential handling for cross-origin requests

### 5. **Fetch API keepalive**
- **Your script**: Missing `keepalive: true`
- **Official**: Includes `keepalive: true` in fetch options
- **Impact**: Your script may not reliably send events when page is unloading/closing

### 6. **beforeSend Callback Handling**
- **Your script**: Synchronous - `payload = callback(type, payload)`
- **Official**: Async - `payload = await Promise.resolve(callback(type, payload))`
- **Impact**: Your script doesn't support async beforeSend callbacks

### 7. **Variable Naming**
- **Your script**: Uses `_true` constant
- **Official**: Uses `_false` and `_true` constants
- **Impact**: Minor - your script hardcodes `"false"` check inline

### 8. **Code Structure**
- **Your script**: Click handlers are initialized inline within `init()`
- **Official**: Separated into `handleClicks()` function for better organization
- **Impact**: Minor - readability only

### 9. **URL Initialization**
- **Your script**: `currentUrl = href` (raw)
- **Official**: `currentUrl = normalize(href)` (normalized)
- **Impact**: Initial page load URL may not respect exclude-search/exclude-hash settings

---

## Summary

### Critical Issues:
1. ❌ **Hardcoded endpoint** - may not work with your Umami installation
2. ❌ **Missing URL normalization** - can crash with invalid URLs
3. ❌ **Missing keepalive** - unreliable tracking on page unload
4. ❌ **No async beforeSend support** - breaks async callbacks

### Minor Issues:
1. ⚠️ Missing `data-fetch-credentials` support
2. ⚠️ No normalization on initial URL
3. ℹ️ Code organization differences

---

## Recommendations

Your script appears to be an **older or custom-modified version** of the Umami tracker. I recommend:

1. **Use the official tracker** from the Umami repository
2. If you need customizations, fork the official version and apply your changes
3. If you must use your current script, add:
   - URL normalization with error handling
   - `keepalive: true` in fetch options
   - Async support for beforeSend
   - Configurable endpoint via build-time replacement

---

## Side-by-Side Critical Code Sections

### URL Handling (Your Script - BROKEN)
```javascript
currentUrl = new URL(url, location.href);
if (excludeSearch) currentUrl.search = "";
if (excludeHash) currentUrl.hash = "";
currentUrl = currentUrl.toString(); // Will crash if URL is invalid
```

### URL Handling (Official - SAFE)
```javascript
const normalize = raw => {
  if (!raw) return raw;
  try {
    const u = new URL(raw, location.href);
    if (excludeSearch) u.search = '';
    if (excludeHash) u.hash = '';
    return u.toString();
  } catch {
    return raw; // Fallback to original value
  }
};

currentUrl = normalize(new URL(url, location.href).toString());
```

### Fetch Options (Your Script - MISSING KEEPALIVE)
```javascript
fetch(endpoint, {
  method: "POST",
  body: JSON.stringify({ type, payload }),
  headers: { /* ... */ },
  credentials: "omit" // Hardcoded
})
```

### Fetch Options (Official - COMPLETE)
```javascript
fetch(endpoint, {
  keepalive: true, // ✅ Ensures reliability
  method: 'POST',
  body: JSON.stringify({ type, payload }),
  headers: { /* ... */ },
  credentials, // ✅ Configurable
})
```
