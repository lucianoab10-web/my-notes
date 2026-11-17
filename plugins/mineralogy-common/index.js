import fs from "node:fs"
import path from "node:path"

const SOURCE_BASE = "https://lucianoab10-web.github.io/my-notes/"

function decode(value) {
  try { return decodeURIComponent(value) } catch { return value }
}

export function normalizedKey(value) {
  return decode(String(value)).replace(/\\/g, "/").replace(/^\/+|\/+$/g, "")
    .replace(/\.(md|html)$/i, "").normalize("NFC").toLowerCase()
}

function stripRelative(value) {
  return value.replace(/^(?:(?:\.\.?\/)+)/, "").replace(/^\//, "")
}

export function loadMap(mapPath = "site-data/mineralogy-links.json") {
  const result = JSON.parse(fs.readFileSync(path.resolve(mapPath), "utf8").replace(/^\uFEFF/, ""))
  if (result.version !== 1 || !Array.isArray(result.entries) || !result.baseUrl) {
    throw new Error("Invalid mineralogy link map. Run the notes publication script first.")
  }
  const base = new URL(result.baseUrl)
  if (base.protocol !== "https:") throw new Error("Mineralogy destinations must use HTTPS.")
  for (const entry of result.entries) {
    const target = new URL(entry.url)
    if (target.origin !== base.origin || !target.pathname.startsWith(base.pathname)) {
      throw new Error(`Mineralogy destination is outside the configured wiki: ${entry.source}`)
    }
  }
  return result
}

function register(index, key, entry) {
  const existing = index.get(key)
  if (existing === undefined) index.set(key, entry)
  else if (existing && existing.url !== entry.url) index.set(key, null)
}

function mappedHash(entry, fragment) {
  if (!fragment) return ""
  const decoded = decode(fragment)
  const anchors = entry.anchors ?? {}
  const mapped = anchors[decoded] ?? anchors[decoded.normalize("NFC").toLowerCase()]
  return "#" + (mapped === undefined ? fragment : encodeURIComponent(mapped))
}

export function createResolver(map, slugifyFilePath, options = {}) {
  const sourceBase = new URL(options.sourceBaseUrl ?? SOURCE_BASE)
  const index = new Map()
  for (const entry of map.entries) {
    for (const identity of [entry.source, ...(entry.keys ?? []), ...(entry.redirects ?? [])]) {
      if (!identity) continue
      register(index, normalizedKey(identity), entry)
      register(index, normalizedKey(slugifyFilePath(identity)), entry)
    }
  }
  return function resolve(href, currentSlug = "", allSlugs = []) {
    if (typeof href !== "string" || !href || href.startsWith("#") || href.startsWith("//")) return null
    let value = href
    let legacyAbsolute = false
    if (/^[a-z][a-z\d+.-]*:/i.test(value)) {
      let absolute
      try { absolute = new URL(value) } catch { return null }
      if (absolute.origin !== sourceBase.origin || !absolute.pathname.startsWith(sourceBase.pathname)) return null
      value = absolute.pathname.slice(sourceBase.pathname.length) + absolute.search + absolute.hash
      legacyAbsolute = true
    } else if (value.startsWith(sourceBase.pathname)) {
      value = value.slice(sourceBase.pathname.length)
      legacyAbsolute = true
    }
    const hashIndex = value.indexOf("#")
    const fragment = hashIndex < 0 ? "" : value.slice(hashIndex + 1)
    const beforeHash = hashIndex < 0 ? value : value.slice(0, hashIndex)
    const queryIndex = beforeHash.indexOf("?")
    const query = queryIndex < 0 ? "" : beforeHash.slice(queryIndex)
    const target = queryIndex < 0 ? beforeHash : beforeHash.slice(0, queryIndex)
    const decodedTarget = decode(target).replace(/\\/g, "/")
    if (!decodedTarget || /\.[a-z\d]+$/i.test(decodedTarget) && !/\.(md|html)$/i.test(decodedTarget)) return null
    const stripped = stripRelative(decodedTarget).replace(/\/$/, "")
    const key = normalizedKey(stripped)
    const direct = index.get(key)
    const entry = direct === undefined ? index.get(normalizedKey(slugifyFilePath(stripped))) : direct
    if (!entry) return null
    const generic = !key.includes("/")
    if (generic && !legacyAbsolute) {
      const candidate = normalizedKey(slugifyFilePath(stripped))
      const relative = normalizedKey(path.posix.normalize(path.posix.join(path.posix.dirname(currentSlug), decodedTarget)))
      const collision = allSlugs.some((slug) => {
        const normalized = normalizedKey(slug)
        return normalized === relative || normalized === candidate || normalized.split("/").at(-1) === candidate
      })
      if (collision) return null
    }
    return { entry, url: entry.url + query + mappedHash(entry, fragment) }
  }
}

export function rewriteTree(tree, resolve, currentSlug, allSlugs) {
  function walk(node) {
    if (node.type !== "element" && !Array.isArray(node.children)) return
    if (node.type === "element") {
      const properties = node.properties ?? {}
      if (node.tagName === "blockquote" && (properties.dataUrl || properties["data-url"])) {
        const resolved = resolve(String(properties.dataUrl ?? properties["data-url"]) + String(properties.dataBlock ?? properties["data-block"] ?? ""), currentSlug, allSlugs)
        if (resolved) {
          const label = String(properties.dataEmbedAlias || properties["data-embed-alias"] || resolved.entry.source.replace(/\.md$/i, ""))
          node.properties = { className: ["mineralogy-reference"] }
          node.children = [{ type: "element", tagName: "p", properties: {}, children: [
            { type: "element", tagName: "a", properties: { href: resolved.url }, children: [{ type: "text", value: label }] },
          ] }]
        }
      }
      if (node.tagName === "a" && typeof properties.href === "string") {
        const resolved = resolve(properties.href, currentSlug, allSlugs)
        if (resolved) {
          properties.href = resolved.url
          delete properties["data-slug"]
          const classes = Array.isArray(properties.className) ? properties.className : String(properties.className ?? "").split(/\s+/)
          properties.className = classes.filter((name) => name && !["internal", "internal-link", "broken", "transclude-inner"].includes(name))
          properties["data-mineralogy-link"] = "true"
          node.properties = properties
        }
      }
    }
    for (const child of node.children ?? []) walk(child)
  }
  walk(tree)
}

function escapeHtml(value) {
  return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

export function redirectHtml(entry) {
  const target = escapeHtml(entry.url)
  const serializedEntry = JSON.stringify({ url: entry.url, anchors: entry.anchors ?? {} }).replace(/</g, "\\u003c")
  return `<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(entry.source.replace(/\.md$/i, ""))} · Mineralogy Wiki</title>
<link rel="canonical" href="${target}"><meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url=${target}">
<script>(function(){const entry=${serializedEntry};const target=new URL(entry.url);target.search=location.search;let fragment=location.hash.slice(1);try{fragment=decodeURIComponent(fragment)}catch{}const mapped=entry.anchors[fragment]??entry.anchors[fragment.normalize('NFC').toLowerCase()];target.hash=mapped===undefined?location.hash:mapped;location.replace(target.href)})();</script>
</head><body><p>Esta ficha está en <a href="${target}">Mineralogy Wiki</a>.</p></body></html>\n`
}

export function planRedirects(map, occupiedSlugs = [], aliasSlugs = []) {
  const occupied = new Set([...occupiedSlugs, ...aliasSlugs].map(normalizedKey))
  const planned = new Map()
  for (const entry of map.entries) {
    for (const value of entry.redirects ?? []) {
      const slug = String(value).replace(/^\/+|\/+$/g, "")
      if (!slug || slug.split("/").some((segment) => !segment || segment === "." || segment === "..") || /[\\:?#<>"|*]/.test(slug)) {
        throw new Error(`Unsafe mineral redirect slug: ${value}`)
      }
      const key = normalizedKey(slug)
      if (occupied.has(key) || occupied.has(key + "/index")) continue
      register(planned, slug, entry)
    }
  }
  const result = []
  for (const [slug, entry] of planned) {
    if (!entry) continue
    result.push({ slug, file: slug + ".html", entry })
    if (![...occupied].some((existing) => existing.startsWith(normalizedKey(slug) + "/"))) {
      result.push({ slug, file: slug + "/index.html", entry })
    }
  }
  return result
}
