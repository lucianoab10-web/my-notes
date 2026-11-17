import fs from "node:fs/promises"
import path from "node:path"
import { simplifySlug } from "@quartz-community/utils"
import { loadMap, planRedirects, redirectHtml } from "../mineralogy-common/index.js"

export const manifest = {
  name: "mineralogy-redirects", displayName: "Mineralogy Wiki redirects", version: "1.0.0",
  category: "emitter", defaultOrder: 95,
}

export default function MineralogyRedirects(options = {}) {
  return {
    name: "MineralogyRedirects",
    async emit(ctx, content) {
      const map = loadMap(options.mapPath)
      const occupied = [...(ctx.allSlugs ?? []), ...content.map(([, file]) => file.data.slug).filter(Boolean)]
      const aliases = content.flatMap(([, file]) => (file.data.aliases ?? []).map((alias) =>
        /^\.{1,2}\//.test(alias) ? path.posix.normalize(path.posix.join(simplifySlug(file.data.slug ?? ""), "..", alias)) : alias,
      ))
      const outputRoot = path.resolve(ctx.argv.output)
      const written = []
      for (const redirect of planRedirects(map, occupied, aliases)) {
        const destination = path.resolve(outputRoot, redirect.file)
        if (!destination.startsWith(outputRoot + path.sep)) throw new Error("Redirect outside Quartz output.")
        await fs.mkdir(path.dirname(destination), { recursive: true })
        await fs.writeFile(destination, redirectHtml(redirect.entry), "utf8")
        written.push(destination)
      }
      return written
    },
  }
}
