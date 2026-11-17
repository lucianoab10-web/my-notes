import fs from 'node:fs/promises'
import path from 'node:path'
import { createRequire } from 'node:module'
import { pathToFileURL, fileURLToPath } from 'node:url'

// Resolve from the Quartz checkout when running a staged copy for verification.
export async function loadDependencies(root = process.cwd()) {
  const require = createRequire(path.join(path.resolve(root), 'package.json'))
  const load = (name) => import(pathToFileURL(require.resolve(name)).href)
  const utilsPath = path.join(path.dirname(require.resolve('@quartz-community/utils/package.json')), 'dist/path.js')
  const [yaml, utils, github, unified, remark, glob] = await Promise.all([
    load('yaml'), import(pathToFileURL(utilsPath).href), load('github-slugger'),
    load('unified'), load('remark-parse'), load('minimatch'),
  ])
  return { parseYaml: yaml.parse, slugifyFilePath: utils.slugifyFilePath,
    GithubSlugger: github.default, parser: unified.unified().use(remark.default),
    minimatch: glob.minimatch }
}

const normalize = (value) => String(value).replaceAll('\\', '/').normalize('NFC').toLowerCase()
const withoutMd = (value) => value.replace(/\.md$/, '')

function safeIdentity(value) {
  return typeof value === 'string' && value.trim() && !/[\r\n#?]/.test(value) &&
    !/^[a-z]+:/i.test(value) && !value.split(/[\\/]/).some((part) => part === '..' || part.startsWith('.'))
}

export function splitFrontmatter(markdown, parseYaml) {
  const match = markdown.replace(/^\uFEFF/, '').match(/^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/)
  if (!match) return { metadata: {}, body: markdown }
  const metadata = parseYaml(match[1]) || {}
  if (typeof metadata !== 'object' || Array.isArray(metadata)) throw new Error('Frontmatter must be a YAML mapping.')
  return { metadata, body: markdown.replace(/^\uFEFF/, '').slice(match[0].length) }
}

// Matches Markdown's default toc.slugify: NFKD ASCII, punctuation removed.
export function mkdocsHeadingSlug(text) {
  return text.normalize('NFKD').replace(/[^\x00-\x7F]/g, '').replace(/[^\w\s-]/g, '')
    .trim().toLowerCase().replace(/[-\s]+/g, '-')
}

function textOf(node) {
  if (node.type === 'html') return ''
  if (node.type === 'image') return node.alt || ''
  if (node.value != null) return node.value
  return (node.children || []).map(textOf).join('')
}

export function headingAnchors(body, deps) {
  const github = new deps.GithubSlugger()
  const used = new Set()
  const candidates = new Map()
  function add(key, anchor) {
    if (!key) return
    if (!candidates.has(key)) candidates.set(key, new Set())
    candidates.get(key).add(anchor)
  }
  for (const node of deps.parser.parse(body).children) {
    if (node.type !== 'heading') continue
    const text = textOf(node)
    let anchor = mkdocsHeadingSlug(text)
    while (!anchor || used.has(anchor)) {
      const count = anchor.match(/^(.*)_(\d+)$/)
      anchor = count ? `${count[1]}_${Number(count[2]) + 1}` : `${anchor}_1`
    }
    used.add(anchor)
    // Explicit heading IDs take priority in MkDocs; do not invent support when
    // attr_list is not enabled in this wiki's config.
    add(github.slug(text), anchor)
    add(text, anchor)
    add(anchor, anchor)
  }
  return Object.fromEntries([...candidates].filter(([, values]) => values.size === 1)
    .map(([key, values]) => [key, [...values][0]]))
}

export function mkdocsPageUrl(source, baseUrl, directoryUrls = true) {
  const name = path.posix.basename(source)
  const folder = path.posix.dirname(source)
  const stem = withoutMd(name)
  const isIndex = name === 'index.md' || name === 'README.md'
  let target = isIndex ? (folder === '.' ? '' : folder + '/') :
    (folder === '.' ? '' : folder + '/') + stem + (directoryUrls ? '/' : '.html')
  if (isIndex && !directoryUrls) target += 'index.html'
  const encodeSegment = (segment) => encodeURIComponent(segment).replace(/[!'()*]/g,
    (character) => '%' + character.charCodeAt(0).toString(16).toUpperCase())
  return new URL(target.split('/').map(encodeSegment).join('/'), baseUrl).href
}

function exclusionMatcher(config, minimatch) {
  const raw = config.exclude_docs || ''
  if (typeof raw !== 'string') throw new Error('exclude_docs must be a multiline string.')
  const patterns = raw.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#'))
  return (relative) => {
    let excluded = relative.split('/').some((part) => part.startsWith('.'))
    for (const rule of patterns) {
      const negate = rule.startsWith('!')
      let pattern = negate ? rule.slice(1) : rule
      pattern = pattern.replace(/^\//, '')
      if (pattern.endsWith('/')) pattern += '**'
      const options = { dot: true, matchBase: !pattern.includes('/') }
      if (minimatch(relative, pattern, options) ||
          relative.split('/').slice(0, -1).some((_, i, parts) => minimatch(parts.slice(0, i + 1).join('/'), pattern, options))) {
        excluded = !negate
      }
    }
    return excluded
  }
}

async function markdownFiles(source) {
  const found = []
  async function walk(folder, prefix = '') {
    for (const entry of await fs.readdir(folder, { withFileTypes: true })) {
      if (entry.isSymbolicLink()) continue
      const relative = prefix + entry.name
      if (entry.isDirectory()) {
        if (!entry.name.startsWith('.')) await walk(path.join(folder, entry.name), relative + '/')
      } else if (entry.isFile() && entry.name.endsWith('.md')) found.push(relative)
    }
  }
  await walk(source)
  return found.sort((a, b) => a.localeCompare(b, 'en'))
}

export async function generateMap({ source, configPath, deps }) {
  const stat = await fs.stat(source).catch(() => null)
  if (!stat?.isDirectory()) throw new Error(`Missing mineral Markdown source folder: ${source}`)
  const config = deps.parseYaml(await fs.readFile(configPath, 'utf8'))
  if (!config || typeof config.site_url !== 'string') throw new Error('MkDocs configuration must contain site_url.')
  const site = new URL(config.site_url)
  if (!['https:', 'http:'].includes(site.protocol)) throw new Error('site_url must be an HTTP(S) website.')
  if (!site.pathname.endsWith('/')) site.pathname += '/'
  site.search = ''; site.hash = ''
  const baseUrl = site.href
  const excluded = exclusionMatcher(config, deps.minimatch)
  let paths = (await markdownFiles(source)).filter((relative) => !excluded(relative))
  const diagnostics = []
  const pathSet = new Set(paths)
  paths = paths.filter((relative) => {
    if (path.posix.basename(relative) === 'README.md') {
      const index = path.posix.join(path.posix.dirname(relative), 'index.md')
      if (pathSet.has(index)) {
        diagnostics.push(`README shadowed by index: ${relative}`)
        return false
      }
    }
    return true
  })
  if (!paths.length) throw new Error('Mineral source contains no public Markdown pages; map was not replaced.')
  const entries = []
  for (const relative of paths) {
    const { metadata, body } = splitFrontmatter(await fs.readFile(path.join(source, relative), 'utf8'), deps.parseYaml)
    const aliases = metadata.aliases == null ? [] : typeof metadata.aliases === 'string' ? [metadata.aliases] : metadata.aliases
    if (!Array.isArray(aliases) || aliases.some((item) => typeof item !== 'string')) throw new Error(`aliases must contain strings: ${relative}`)
    const stem = withoutMd(relative)
    const basename = path.posix.basename(stem)
    const names = [stem, basename, ...aliases.filter(safeIdentity)]
    const keys = new Set()
    for (const name of names) {
      keys.add(name); keys.add(name + '.md')
      keys.add(deps.slugifyFilePath(name + '.md'))
    }
    for (const prefix of ['compartidos/second-brain/markdowns/', 'second-brain/markdowns/', 'markdowns/']) {
      keys.add(prefix + stem); keys.add(prefix + relative)
      keys.add(deps.slugifyFilePath(prefix + relative))
    }
    const redirects = new Set(names.map((name) => deps.slugifyFilePath(name + '.md')))
    redirects.delete('index'); redirects.delete('')
    entries.push({ source: relative, url: mkdocsPageUrl(relative, baseUrl, config.use_directory_urls !== false),
      keys: [...keys].sort(), redirects: [...redirects].sort(), anchors: headingAnchors(body, deps) })
  }
  // Bare aliases shared by two files are unsafe; their explicit source paths
  // remain available. Redirect collisions are omitted instead of picking one.
  for (const field of ['keys', 'redirects']) {
    const owners = new Map()
    for (const entry of entries) for (const value of entry[field]) {
      const key = normalize(value)
      if (!owners.has(key)) owners.set(key, new Set())
      owners.get(key).add(entry.url)
    }
    const ambiguous = new Set([...owners].filter(([, urls]) => urls.size > 1).map(([key]) => key))
    for (const entry of entries) entry[field] = entry[field].filter((value) => !ambiguous.has(normalize(value)))
    for (const value of ambiguous) diagnostics.push(`Ambiguous ${field === 'keys' ? 'identity' : 'redirect'} omitted: ${value}`)
  }
  return { version: 1, baseUrl, entries, diagnostics: diagnostics.sort() }
}

export async function main(args = process.argv.slice(2)) {
  const options = {}
  for (let index = 0; index < args.length; index += 2) {
    if (!['--source', '--config', '--output'].includes(args[index]) || !args[index + 1]) throw new Error('Usage: --source <folder> --config <mkdocs.yml> --output <map.json>')
    options[args[index].slice(2)] = path.resolve(args[index + 1])
  }
  if (!options.source || !options.config || !options.output) throw new Error('Usage: --source <folder> --config <mkdocs.yml> --output <map.json>')
  const deps = await loadDependencies()
  const map = await generateMap({ source: options.source, configPath: options.config, deps })
  await fs.mkdir(path.dirname(options.output), { recursive: true })
  const temporary = options.output + `.tmp-${process.pid}`
  await fs.writeFile(temporary, JSON.stringify(map, null, 2) + '\n', 'utf8')
  await fs.rename(temporary, options.output)
  console.log(`Mineralogy connections: ${map.entries.length} wiki pages; ${map.diagnostics.length} ambiguity/exclusion notices.`)
  for (const notice of map.diagnostics) console.log(`  ${notice}`)
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1 })
}
