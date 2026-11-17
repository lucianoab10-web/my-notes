import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import path from 'node:path'
import os from 'node:os'
import { loadDependencies, generateMap, mkdocsPageUrl, headingAnchors } from './generate-mineralogy-map.mjs'

const deps = await loadDependencies()

async function fixture(t, pages, config = 'site_url: https://example.test/mineralogy-wiki/\n') {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'mineral-map-'))
  t.after(async () => {
    const resolved = await fs.realpath(root)
    const temporaryRoot = await fs.realpath(os.tmpdir())
    assert.ok(resolved.toLowerCase().startsWith((temporaryRoot + path.sep + 'mineral-map-').toLowerCase()))
    await fs.rm(resolved, { recursive: true, force: true })
  })
  const source = path.join(root, 'source')
  await fs.mkdir(source)
  for (const [relative, markdown] of Object.entries(pages)) {
    const target = path.join(source, relative)
    await fs.mkdir(path.dirname(target), { recursive: true })
    await fs.writeFile(target, markdown)
  }
  const configPath = path.join(root, 'mkdocs.yml')
  await fs.writeFile(configPath, config)
  return { root, source, configPath, deps }
}

test('real destination spelling and accented paths preserve MkDocs URLs', async (t) => {
  const map = await generateMap(await fixture(t, {
    'Moscovita.md': '# Moscovita\n', 'sub/Anfíboles Amp.md': '# Anfíboles\n',
  }))
  const mica = map.entries.find((entry) => entry.source === 'Moscovita.md')
  assert.equal(mica.url, 'https://example.test/mineralogy-wiki/Moscovita/')
  assert.ok(mica.redirects.includes('moscovita'))
  assert.ok(mica.keys.includes('compartidos/second-brain/markdowns/Moscovita.md'))
  assert.equal(map.entries[1].url, 'https://example.test/mineralogy-wiki/sub/Anf%C3%ADboles%20Amp/')
  assert.equal(mkdocsPageUrl('abreviaturas minerales (EN).md', map.baseUrl),
    'https://example.test/mineralogy-wiki/abreviaturas%20minerales%20%28EN%29/')
})

test('only explicit frontmatter aliases identify alternate mineral names', async (t) => {
  const map = await generateMap(await fixture(t, {
    'Moscovita.md': '---\naliases:\n  - Muscovite\n  - Mica blanca\n---\n# Potassium mica\n',
  }))
  assert.ok(map.entries[0].keys.includes('Muscovite'))
  assert.ok(map.entries[0].redirects.includes('mica-blanca'))
  assert.ok(!map.entries[0].keys.includes('Potassium mica'))
})

test('duplicate basenames and aliases keep qualified paths, omit ambiguous short matches', async (t) => {
  const map = await generateMap(await fixture(t, {
    'a/Mica.md': '---\naliases: Mica común\n---\n',
    'b/Mica.md': '---\naliases: Mica común\n---\n',
  }))
  for (const entry of map.entries) {
    assert.ok(!entry.keys.includes('Mica'))
    assert.ok(!entry.redirects.includes('mica'))
    assert.ok(!entry.keys.includes('Mica común'))
    assert.ok(entry.keys.includes(entry.source))
  }
  assert.ok(map.diagnostics.some((notice) => notice.includes('identity omitted: mica')))
})

test('README and index map to MkDocs folder homes with index taking precedence', async (t) => {
  const map = await generateMap(await fixture(t, {
    'README.md': '# old home', 'index.md': '# home', 'guide/README.md': '# guide',
  }))
  assert.ok(!map.entries.some((entry) => entry.source === 'README.md'))
  assert.equal(map.entries.find((entry) => entry.source === 'index.md').url, 'https://example.test/mineralogy-wiki/')
  assert.equal(map.entries.find((entry) => entry.source === 'guide/README.md').url, 'https://example.test/mineralogy-wiki/guide/')
  assert.ok(!map.entries.flatMap((entry) => entry.redirects).includes('index'))
  assert.equal(mkdocsPageUrl('guide/README.md', map.baseUrl, false), 'https://example.test/mineralogy-wiki/guide/index.html')
  assert.equal(mkdocsPageUrl('Moscovita.md', map.baseUrl, false), 'https://example.test/mineralogy-wiki/Moscovita.html')
})

test('hidden files and MkDocs exclude_docs are excluded', async (t) => {
  const map = await generateMap(await fixture(t, {
    'Moscovita.md': '# mica', '.secret.md': '# no', 'private/hidden.md': '# no',
    'draft.md': '# no', 'private/allowed.md': '# permitted',
  }, 'site_url: https://example.test/wiki/\nexclude_docs: |\n  private/\n  !private/allowed.md\n  draft.md\n'))
  assert.deepEqual(map.entries.map((entry) => entry.source).sort(), ['Moscovita.md', 'private/allowed.md'])
})

test('heading anchors reconcile accent and duplicate numbering without reading fences', () => {
  const anchors = headingAnchors('# Diagnóstico\n\n## Propiedades\n\n## Propiedades\n\n```md\n# Fake\n```\n', deps)
  assert.equal(anchors['diagnóstico'], 'diagnostico')
  assert.equal(anchors['Diagnóstico'], 'diagnostico')
  assert.equal(anchors['propiedades'], 'propiedades')
  assert.equal(anchors['propiedades-1'], 'propiedades_1')
  assert.ok(!('Propiedades' in anchors))
  assert.ok(!('fake' in anchors))
})

test('malformed metadata, empty input, and missing input fail explicitly', async (t) => {
  const empty = await fixture(t, {})
  await assert.rejects(generateMap(empty), /no public Markdown/)
  await assert.rejects(generateMap({ ...empty, source: path.join(empty.root, 'missing') }), /Missing mineral Markdown/)
  await assert.rejects(generateMap({ ...empty, configPath: path.join(empty.root, 'missing.yml') }), /ENOENT/)
  const malformed = await fixture(t, { 'Mica.md': '---\naliases: [Mica, 42]\n---\n' })
  await assert.rejects(generateMap(malformed), /aliases must contain strings/)
})

test('no-directory URLs and site path normalize from configuration', async (t) => {
  const map = await generateMap(await fixture(t, { 'Mica.md': '# mica' },
    'site_url: https://example.test/wiki\nuse_directory_urls: false\n'))
  assert.equal(map.baseUrl, 'https://example.test/wiki/')
  assert.equal(map.entries[0].url, 'https://example.test/wiki/Mica.html')
})
