import test from "node:test"
import assert from "node:assert/strict"
import vm from "node:vm"
import { createResolver, rewriteTree, planRedirects, redirectHtml } from "../mineralogy-common/index.js"

// Matching production Quartz's current spelling rules, injected so this core test has no dependencies.
const slugify = (value) => value.replace(/^\/+|\/+$/g, "").replace(/\.(md|html)$/i, "").split("/").map((segment) => segment.replace(/\s/g, "-").replace(/&/g, "-and-").replace(/%/g, "-percent").replace(/\?/g, "").replace(/#/g, "").replace(/[<>:"|*]/g, "").toLowerCase()).join("/")
const mica = {
  source: "Moscovita.md", url: "https://lucianoab10-web.github.io/mineralogy-wiki/Moscovita/",
  keys: ["Moscovita", "Muscovite", "compartidos/second-brain/markdowns/Moscovita"],
  redirects: ["moscovita", "muscovite"], anchors: { "diagnóstico": "diagnostico", "propiedades": "propiedades" },
}
const map = { version: 1, baseUrl: "https://lucianoab10-web.github.io/mineralogy-wiki/", entries: [mica] }
const resolve = createResolver(map, slugify)

test("mineral links retain aliases and map accented heading anchors", () => {
  const anchor = { type: "element", tagName: "a", properties: { href: "Moscovita#diagn%C3%B3stico", className: ["internal", "alias"], "data-slug": "moscovita" }, children: [{ type: "text", value: "mica clara" }] }
  rewriteTree({ type: "root", children: [anchor] }, resolve, "clases/apuntes", ["clases/apuntes"])
  assert.equal(anchor.properties.href, mica.url + "#diagnostico")
  assert.equal(anchor.children[0].value, "mica clara")
  assert.deepEqual(anchor.properties.className, ["alias"])
  assert.equal(anchor.properties["data-slug"], undefined)
})

test("explicit vault paths and markdown filenames resolve to the same destination", () => {
  for (const target of ["Moscovita.md", "../Moscovita.md", "compartidos/second-brain/markdowns/Moscovita.md", "Muscovite"]) {
    assert.equal(resolve(target, "notes/apunte", ["notes/apunte"])?.url, mica.url)
  }
})

test("generic mineral names yield to actual local pages", () => {
  assert.equal(resolve("Moscovita", "clases/notas", ["clases/moscovita"]), null)
  assert.equal(resolve("../Moscovita.md", "clases/notas", ["moscovita"]), null)
  assert.equal(resolve("compartidos/second-brain/markdowns/Moscovita", "clases/notas", ["clases/moscovita"])?.url, mica.url)
})

test("legacy absolute and site-root URLs resolve while unrelated external links stay unchanged", () => {
  assert.equal(resolve("https://lucianoab10-web.github.io/my-notes/moscovita?view=1#diagnóstico")?.url, mica.url + "?view=1#diagnostico")
  assert.equal(resolve("/my-notes/moscovita.html")?.url, mica.url)
  for (const value of ["https://example.com/Moscovita", "https://lucianoab10-web.github.io/my-notes-other/moscovita", "#propiedades", "mailto:mica@example.com", "//example.com/moscovita", "Moscovita.png", "foo/Moscovita"]) assert.equal(resolve(value), null)
})

test("ambiguous aliases never select an arbitrary destination", () => {
  const conflict = { ...mica, source: "Otro.md", url: map.baseUrl + "Otro/", keys: ["Moscovita"], redirects: [] }
  assert.equal(createResolver({ ...map, entries: [mica, conflict] }, slugify)("Moscovita"), null)
})

test("unknown anchors are preserved instead of inventing a destination", () => {
  assert.equal(resolve("Moscovita#mi-bloque")?.url, mica.url + "#mi-bloque")
})

test("cross-site mineral embeds become readable links with their display alias", () => {
  const embed = { type: "element", tagName: "blockquote", properties: { className: ["transclude"], dataUrl: "moscovita", dataBlock: "#diagnóstico", dataEmbedAlias: "mi ficha" }, children: [] }
  rewriteTree({ type: "root", children: [embed] }, resolve, "apunte", ["apunte"])
  assert.deepEqual(embed.properties, { className: ["mineralogy-reference"] })
  assert.equal(embed.children[0].children[0].properties.href, mica.url + "#diagnostico")
  assert.equal(embed.children[0].children[0].children[0].value, "mi ficha")
})

test("redirects cover extensionless and trailing-slash visits", () => {
  assert.deepEqual(planRedirects(map).map(({ file }) => file), ["moscovita.html", "moscovita/index.html", "muscovite.html", "muscovite/index.html"])
})

test("redirects do not overwrite local pages, folder indexes, aliases, or descendant pages", () => {
  assert.deepEqual(planRedirects(map, ["moscovita"], ["muscovite"]), [])
  assert.deepEqual(planRedirects(map, ["moscovita/index", "muscovite/index"]), [])
  assert.ok(!planRedirects(map, ["moscovita/details"]).some(({ file }) => file === "moscovita/index.html"))
})

test("conflicting redirects are omitted and unsafe output paths are rejected", () => {
  const other = { ...mica, url: map.baseUrl + "Other/", redirects: ["moscovita"] }
  assert.ok(!planRedirects({ ...map, entries: [mica, other] }).some(({ slug }) => slug === "moscovita"))
  for (const redirect of ["../outside", "nested/../outside", "foo\\bar", "C:/foo", "foo?bad"]) {
    assert.throws(() => planRedirects({ ...map, entries: [{ ...mica, redirects: [redirect] }] }), /Unsafe/)
  }
})

test("redirect page has fallback, canonical, and functional query/hash preservation", () => {
  const html = redirectHtml(mica)
  assert.ok(html.includes('<link rel="canonical" href="' + mica.url + '">'))
  assert.ok(html.includes('<meta http-equiv="refresh" content="0; url=' + mica.url + '">'))
  assert.ok(html.includes('<a href="' + mica.url + '">'))
  let destination
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1]
  vm.runInNewContext(script, { URL, location: { search: "?from=old", hash: "#diagn%C3%B3stico", replace(value) { destination = value } } })
  assert.equal(destination, mica.url + "?from=old#diagnostico")
})

test("redirect HTML escapes destination and script-breaking source content", () => {
  const html = redirectHtml({ ...mica, source: '<script>bad</script>.md', anchors: { bad: '</script><script>bad</script>' } })
  assert.equal((html.match(/<script>/g) ?? []).length, 1)
  assert.ok(html.includes("&lt;script&gt;"))
})
